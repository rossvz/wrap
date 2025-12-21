namespace :users do
  desc "Assign all orphan habits to a user (creates user if email provided)"
  task :adopt_habits, [ :email ] => :environment do |t, args|
    email = args[:email]

    if email.blank?
      puts "Usage: bin/rails users:adopt_habits[email@example.com]"
      puts "This will create a user (if needed) and assign all habits without a user to them."
      exit 1
    end

    user = User.find_or_create_by!(email_address: email)
    orphan_habits = Habit.where(user_id: nil)
    count = orphan_habits.count

    if count == 0
      puts "No orphan habits found. All habits already have owners."
      exit 0
    end

    orphan_habits.update_all(user_id: user.id)
    puts "Assigned #{count} habit(s) to #{user.email_address} (id: #{user.id})"
  end

  desc "List all users"
  task list: :environment do
    users = User.all.order(:created_at)

    if users.empty?
      puts "No users found."
      exit 0
    end

    puts "Users:"
    puts "-" * 60
    users.each do |user|
      habit_count = user.habits.count
      puts "#{user.id}: #{user.email_address} (#{habit_count} habits)"
    end
  end

  desc "Clean up stale magic links"
  task cleanup_magic_links: :environment do
    count = MagicLink.cleanup
    puts "Deleted #{count} stale magic link(s)."
  end
end
