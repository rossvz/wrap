class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "noreply@wrap.rosscodes.com")
  layout "mailer"
end
