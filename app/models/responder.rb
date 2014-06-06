class Responder < User
  # RELATIONS #
  has_many :reports, through: :dispatches
  has_many :dispatches

  # VALIDATIONS #
  validates_presence_of :phone

  # CALLBACKS #
  after_validation :make_unavailable!, :on => :update, if: :need_to_make_unavailable?

  # SCOPES #
  default_scope -> { where(role: 'responder') }
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  scope :available, -> do
    joins(:dispatches).where(availability: 'available')
      .where.not('dispatches.status = (?) OR dispatches.status = (?)', 'pending', 'active')
  end

  # INSTANCE METHODS #
  def phone=(new_phone)
    write_attribute :phone, NumberSanitizer.sanitize(new_phone)
  end

  def respond(body)
    give_feedback(body)

    return latest_dispatch.reject! if latest_dispatch.pending? && body.match(/no/i)
    return latest_dispatch.complete! if latest_dispatch.accepted? && body.match(/done/i)
    latest_dispatch.accept! unless latest_dispatch.accepted? || latest_dispatch.completed?
  end

  def completed_count
    dispatches.where(status: "completed").count
  end

  def rejected_count
    dispatches.where(status: "rejected").count
  end

  def available?
    availability == 'available'
  end

  def unavailable?
    availability == 'unavailable'
  end

  def status
    return "unassigned" if dispatches.none?

    last_dispatch = dispatches.order("created_at desc").first
    "last: #{last_dispatch.status}"
  end

  def set_password
    self.password              = 'password'
    self.password_confirmation = 'password'
  end

  private

  def latest_dispatch
    dispatches.latest
  end

  def give_feedback(body)
    latest_dispatch.report.accept_feedback(from: self, body: body)
  end

  def make_unavailable!
    update_attribute(:availability, false)
  end

  def need_to_make_unavailable?
    active_changed? && !active
  end
end
