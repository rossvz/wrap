class MagicLinkMailer < ApplicationMailer
  def sign_in_code(magic_link)
    @magic_link = magic_link
    @code = magic_link.code

    mail(
      to: magic_link.user.email_address,
      subject: "Your sign-in code for Wrap"
    )
  end
end
