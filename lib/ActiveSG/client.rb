module ActiveSG
	class Client
		attr :username, true
		attr :password, true

		def say_hello
			puts 'Hello'
		end

		def login
			puts @username
			puts @password
		end

		def available_slots_on(date)
			puts date.to_s
		end

		def book_slot(slot_id)
			puts slot_id
		end

		def logout
		end
	end
end