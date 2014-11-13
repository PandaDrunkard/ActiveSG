require "net/https"

module ActiveSG
	class Client
		attr :username, true
		attr :password, true

		@@cookie = {}
		def get_cookie(res)
			res.get_fields('Set-Cookie').each{ |str|
				k,v = str[0...str.index(';')].split('=')
				@@cookie[k] = v
			}
		end
		def set_cookie()
			@@cookie.map{ |k,v| "#{k}=#{v}" }.join(';')
		end

		def login
			uri = URI.parse("https://members.myactivesg.com/auth/signin")
			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_PEER

			header = {
				"Content-Type" => "application/x-www-form-urlencoded"
			}

			req = Net::HTTP::Post.new(uri.path, header)
			req.body = "email=" + URI.escape(@username) + "&password=" + URI.escape(@password)

			res = http.start { |http| http.request(req) }
			get_cookie(res)
		end

		def available_slots_on(date,venue)
			# retrieve location of site
			date_filter = URI.escape("Sun, 22 Nov 2014")
			venue_filter = venue.to_s
			uri = URI.parse("https://members.myactivesg.com/facilities/result?" \
				+ "activity_filter=18" \
				+ "&venue_filter=" + venue_filter \
				+ "&day_filter=1" \
				+ "&date_filter=" + date_filter \
				+ "&search=Search");
			res = Net::HTTP.get_response(uri);
			
			# 
			uri = URI.parse(res['location'])
			puts uri
			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_PEER

			header = {
				"Cookie" => set_cookie
			}
			req = Net::HTTP::Post.new(uri.path, header)
			res = http.start { |http| http.request(req) }
			get_cookie(res)

			File.open("tmp/available_slots_on.html","w") do |file|
				file.write(res.body)
			end
		end

		def book_slot(slot_id)
			puts slot_id
		end

		def logout
			puts 'bye, ' + @username
		end
	end
end