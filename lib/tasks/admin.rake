namespace :app do
  desc "Ensure an admin user exists (requires ADMIN_EMAIL and ADMIN_PASSWORD)"
  task ensure_admin: :environment do
    email = ENV["ADMIN_EMAIL"].to_s.strip
    password = ENV["ADMIN_PASSWORD"].to_s

    if email.blank? || password.blank?
      puts "Skipping admin bootstrap: ADMIN_EMAIL or ADMIN_PASSWORD is missing."
      next
    end

    user = User.find_or_initialize_by(email: email)
    user.password = password
    user.password_confirmation = password
    user.role = :admin
    user.save!

    puts "Ensured admin user: #{user.email} (id=#{user.id})"
  end
end
