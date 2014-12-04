require "net/https"

module ActiveSG
	class Client
		attr :username, true
		attr :password, true

		@@http
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

		def write_to_file(text, path)
			File.open(text, "w") do |file|
				file.write(path)
			end
		end

		def login
			uri = URI.parse("https://members.myactivesg.com/auth/signin")
			@@http = Net::HTTP.new(uri.host, uri.port)
			@@http.use_ssl = true
			@@http.verify_mode = OpenSSL::SSL::VERIFY_PEER

			header = {
				"Content-Type" => "application/x-www-form-urlencoded"
			}

			req = Net::HTTP::Post.new(uri.path, header)
			req.body = "email=" + URI.escape(@username) + "&password=" + URI.escape(@password)

			res = @@http.start { |http| http.request(req) }
			get_cookie(res)
		end

		def get_escaped_date_filter(date)
			escaped = ""
			case date.wday
			when 0
				escaped += "Sun"
			when 1
				escaped += "Mon"
			when 2
				escaped += "Tue"
			when 3
				escaped += "Wed"
			when 4
				escaped += "Thu"
			when 5
				escaped += "Fri"
			when 6
				escaped += "Sat"
			end
			escaped += "%2C+" + date.day.to_s + "+"
			case date.month
			when 1
				escaped += "Jan"
			when 2
				escaped += "Feb"
			when 3
				escaped += "Mar"
			when 4
				escaped += "Apr"
			when 5
				escaped += "May"
			when 6
				escaped += "Jun"
			when 7
				escaped += "Jul"
			when 8
				escaped += "Aug"
			when 9
				escaped += "Sep"
			when 10
				escaped += "Oct"
			when 11
				escaped += "Nov"
			when 12
				escaped += "Dec"
			end
			escaped += "+" + date.year.to_s
			escaped
		end

		def available_slots_on(date,venue)
			# retrieve location of site
			date_filter = get_escaped_date_filter(date)
			venue_filter = venue.to_s
			uri = URI.parse("https://members.myactivesg.com/facilities/result?" \
				+ "activity_filter=18" \
				+ "&venue_filter=" + venue.to_s \
				+ "&day_filter=7" \
				+ "&date_filter=" + date_filter \
				+ "&search=Search");
			res = Net::HTTP.get_response(uri);
			
			uri = URI.parse(res['location'])
			puts uri

			header = {
				"Cookie" => set_cookie
			}
			req = Net::HTTP::Post.new(uri.path, header)
			res = @@http.start { |http| http.request(req) }
			get_cookie(res)

			write_to_file("tmp/available_slots_on.html", res.body)
		end

		def book_slot(slot_id)
			puts slot_id
		end

		def logout
			puts 'bye, ' + @username
		end
	end
end