class Report < ActiveRecord::Base
  belongs_to :responder
  has_many :dispatches

  def self.unassigned
    find_by_sql(%Q{
      SELECT r.*, count(distinct d.id) as ad_count, count(distinct dr.id) as dr_count FROM reports r
        LEFT JOIN dispatches d on d.report_id=r.id
        LEFT JOIN dispatches dr on dr.report_id=r.id AND dr.status='rejected'
      GROUP BY r.id
      HAVING count(distinct d.id) = count(distinct dr.id)
      })
  end

  def self.pending
    joins(:dispatches).where(dispatches: {status: "pending"}).order("created_at desc")
  end

  def self.accepted
    joins(:dispatches).where(dispatches: {status: "accepted"}).order("created_at desc")
  end

  def unassigned?
    dispatches.none? || dispatches.all?(&:rejected?)
  end

  def self.completed
    joins(:dispatches).where(dispatches: {status: "completed"}).order("created_at desc")
  end

  def pending?
    current_dispatch && current_dispatch.pending?
  end

  def accepted?
    current_dispatch && current_dispatch.accepted?
  end

  def completed?
    current_dispatch && current_dispatch.completed?
  end

  def responder_synopsis
    <<-SMS
    CRISIS REPORT:
    #{address}
    #{name}
    #{phone}
    SMS
  end

  def current_dispatch
    dispatches.last
  end

  def reporter_synopsis
    <<-SMS
    CRISIS RESPONSE:
    #{responder.name} is on the way.
    #{responder.phone}
    SMS
  end

  def freshness
    if created_at > 2.minutes.ago
      "fresh"
    elsif created_at > 4.minutes.ago
      "semi-fresh"
    elsif created_at > 9.minutes.ago
      "stale"
    else
      "old"
    end
  end

  def dispatched?
    dispatch.present?
  end

  def status
    if dispatches.none? || dispatches.all(&:rejected?)
      "unassigned"
    else
      dispatch.status
    end
  end

  def accept_feedback(opts={})
    sender = opts[:from]
    additional_feedback = opts[:body]

    update_attributes(feedback: feedback + " | #{sender}: #{additional_feedback}")
  end
end