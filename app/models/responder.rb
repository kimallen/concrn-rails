class Responder < User
  default_scope -> { where(role: 'responder') }
  has_many :reports
  has_many :dispatches
  validates_presence_of :phone

  def self.available
    find_by_sql(%Q{
      SELECT r.*, count(distinct d.id) as ad_count, count(distinct dr.id) as dr_count FROM users r
        LEFT JOIN dispatches d on d.responder_id=r.id
        LEFT JOIN dispatches dr on dr.responder_id=r.id AND dr.status not in ('pending', 'accepted')
      WHERE r.role = 'responder'
      AND r.availability = 'available'
      GROUP BY r.id
      HAVING count(distinct d.id) = count(distinct dr.id)
    })
  end

  def phone=(new_phone)
    write_attribute :phone, NumberSanitizer.sanitize(new_phone)
  end

  def respond(body)
    if latest_dispatch.pending?
      case body
      when /no/
        latest_dispatch.reject!
      else
        latest_dispatch.accept!
      end
    elsif latest_dispatch.accepted?
      case body
      when /done/
        latest_dispatch.finish!
      else
        Rails.logger.info body
      end
    elsif latest_dispatch.completed?
      give_feedback(body)
    end

  end

  def dispatch_to(report)
    Dispatch.create!(report: report, responder: self)
  end

  def completed_count
    dispatches.where(status: "completed").count
  end

  def rejected_count
    dispatches.where(status: "rejected").count
  end

  def status
    return "unassigned" if dispatches.none?
    "last: #{dispatches.order("created_at desc").first.status}"
  end

  private

  def latest_dispatch
    dispatches.latest
  end

  def give_feedback(body)
    latest_dispatch.report.accept_feedback(from: self, body: body)
  end
end