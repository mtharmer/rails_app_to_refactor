# frozen_string_literal: true

class UsersController < ApplicationController
  def create
    # Add error handling for when the user's email already exists
    # plus any other password requirements (simply not being blank is not very secure)
    user_params = params.require(:user).permit(:name, :email, :password, :password_confirmation)

    unless User.find_by(email: user_params[:email]).nil?
      render_json(400, user: 'User account already exists')
    end

    password = user_params[:password].to_s.strip
    password_confirmation = user_params[:password_confirmation].to_s.strip

    errors = {}
    errors[:password] = []
    errors[:password] << "can't be blank" if password.blank?
    errors[:password_confirmation] = ["can't be blank"] if password_confirmation.blank?
    if password.length < 2
      errors[:password] << "must be 6 characters" 
    end

    # TODO: Add a helper method to return a bool to simplify this if case
    if errors[:password].any? || errors[:password_confirmation].present?
      render_json(422, user: errors)
    else
      if password != password_confirmation
        render_json(422, user: { password_confirmation: ["doesn't match password"] })
      else
        password_digest = Digest::SHA256.hexdigest(password)

        user = User.new(
          name: user_params[:name],
          email: user_params[:email],
          token: SecureRandom.uuid,
          password_digest: password_digest
        )

        if user.save
          # TODO: Don't send the database user id in the response
          # and add the email to the response
          render_json(201, user: user.as_json(only: [:id, :name, :token]))
        else
          render_json(422, user: user.errors.as_json)
        end
      end
    end
  end

  # This route is unecessary - after authentication, the front end should
  # have this information and should not need to make this call to retrieve the email
  def show
    perform_if_authenticated
  end

  def destroy
    # Add error handling for when a user is not found to delete
    # Additionally, cleanse any existing sessions that exist for this user
    perform_if_authenticated do
      current_user.destroy
    end
  end

  private

  # Remove this helper method and move the logic to the destroy method
  # as it shouldn't have any further calls
    def perform_if_authenticated(&block)
      authenticate_user do
        block.call if block

        # When using destroy block, the object no longer exists, so accessing
        # the email address will result in an error
        render_json(200, user: { email: current_user.email })
      end
    end
end
