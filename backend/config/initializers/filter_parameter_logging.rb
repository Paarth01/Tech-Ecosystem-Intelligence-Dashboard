# Anything matching these names is replaced with [FILTERED] in logs (request parameters and the
# query string). `token` covers password-reset and email-verification links, `invite_code` is the
# sign-up secret, and `email` keeps addresses out of logs.
Rails.application.config.filter_parameters += %i[
  password password_confirmation current_password token invite_code email secret otp
]
