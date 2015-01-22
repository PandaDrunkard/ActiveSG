require "net/https"

module ActiveSG
	class Client
		attr :username, true
		attr :password, true
		attr :debug, true
		attr :mutex, true

		@@day_of_week = {
			0 => "Sun",
			1 => "Mon",
			2 => "Tue",
			3 => "Wed",
			4 => "Thu",
			5 => "Fri",
			6 => "Sat"
		}
		@@month = {
			1 => "Jan",
			2 => "Feb",
			3 => "Mar",
			4 => "Apr",
			5 => "May",
			6 => "Jun",
			7 => "Jul",
			8 => "Aug",
			9 => "Sep",
			10 => "Oct",
			11 => "Nov",
			12 => "Dec"
		}

		@@http
		@@cookie = {}
		@@slot_url
		@@booking_url
		@@oauth_key
		@@oauth_value
		@@venue_id
		@@date
		@@is_quick_booking = false
		@@referer_url

		def initialize(username, password, debug = false, mutex = nil)
			@username = username
			@password = password
			@debug = debug
			@mutex = mutex

			uri = URI.parse("https://members.myactivesg.com/auth")
			@@http = Net::HTTP.new(uri.host, uri.port)
			@@http.use_ssl = true
			@@http.verify_mode = OpenSSL::SSL::VERIFY_PEER
		end

		def request(req)
			req["Accept_Endocing"] = "gzip, deflate, sdch"
			res = nil
			if @mutex == nil
				res = @@http.request(req)
			else
				@mutex.synchronize { res = @@http.request(req) }
			end
			res
		end

		def write_log(msg)
			puts "#{@username} : #{msg}"
		end

		def get_cookie(res)
			set_cookie_value = res.get_fields('Set-Cookie')
			return if set_cookie_value == nil
			
			res.get_fields('Set-Cookie').each{ |str|
				k,v = str[0...str.index(';')].split('=')
				@@cookie[k] = v
			}
			if @debug
				@@cookie.each{ |k,v|
					write_log k
					write_log v
				}
			end
		end

		def set_cookie()
			@@cookie.map{ |k,v| "#{k}=#{v}" }.join(';')
		end

		def write_to_file(path, text)
			if @debug
				File.open(path, "w") do |file|
					file.write(text)
				end
			end
		end

		def login
			uri = URI.parse("https://members.myactivesg.com/auth")
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Connection" => "keep-alive",
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36"
			}
			req = Net::HTTP::Get.new(uri.path, header)
			res = request(req)
			get_cookie(res)

			write_to_file("tmp/html/auth.html", res.body)

			uri = URI.parse("https://members.myactivesg.com/auth/signin")
			header = {
				"Cookie" => set_cookie,
				"Origin" => "https://members.myactivesg.com",
				"Host" => "members.myactivesg.com",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36",		
				"Content-Type" => "application/x-www-form-urlencoded",
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Cache-Control" => "max-age=0",
				"Referer" => "https://members.myactivesg.com/auth",
				"Connection" => "keep-alive",
				"DNT" => "1"
			}
			req = Net::HTTP::Post.new(uri.path, header)
			req.body = "email=" + URI.escape(@username) + "&password=" + URI.escape(@password)
			res = request(req)
			get_cookie(res)

			write_to_file("tmp/html/auth-signin.html", res.body)
		end

		def available_slots_on(date, venue)
			@@venue_id = venue
			@@date = date

			uri = URI.parse("https://members.myactivesg.com/facilities")
			header = {
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36",
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Referer" => "https://members.myactivesg.com/auth",
				"Cookie" => set_cookie,
				"Connection" => "keep-alive",
			}
			req = Net::HTTP::Get.new(uri.path, header)
			res = request(req)
			get_cookie(res)

			write_to_file("tmp/html/facilities.html", res.body)

			quick_booking = res["Location"] == "https://members.myactivesg.com/facilities/quick-booking"
			
			if quick_booking
				write_log "Quick booking"
				@@is_quick_booking = true
				return slots_by_quick_booking(date, venue)
			else
				write_log "Non-quick booking"
				@@is_quick_booking = false
				return slots_by_normal(date, venue)
			end
		end

		def create_date_filter(date, escape)
			if escape
				@@day_of_week[date.wday] \
					+ "%2C+" + date.day.to_s \
					+ "+" + @@month[date.month] \
					+ "+" + date.year.to_s
			else
				@@day_of_week[date.wday] \
					+ ", " + date.day.to_s \
					+ " " + @@month[date.month] \
					+ " " + date.year.to_s
			end
		end

		def slots_by_quick_booking(date, venue)
			uri = URI.parse("https://members.myactivesg.com/facilities/quick-booking")
			header = {
				"Cookie" => set_cookie,
				"Origin" => "https://members.myactivesg.com",
				"Host" => "members.myactivesg.com",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36",
				"Content-Type" => "application/x-www-form-urlencoded",
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Cache-Control" => "max-age=0",
				"Referer" => "https://members.myactivesg.com/facilities/quick-booking",
				"Connection" => "keep-alive",
				"DNT" => "1",

			}
			form_data = {
				"activity_filter" => "18",
				"venue_filter" => venue.to_s,
				"date_filter" => create_date_filter(date, false)
			}

			req = Net::HTTP::Post.new(uri, header)
			req.set_form_data(form_data)
			res = request(req)
			get_cookie(res)
			@@referer_url = uri.to_s

			write_to_file("tmp/html/quick-booking.html", res.body)

			parse_search_result(res.body)
		end

		def slots_by_normal(date, venue)
			if date.wday == 0
				day_filter = 7
			else
				day_filter = date.wday + 1
			end

			uri = URI.parse("https://members.myactivesg.com/facilities/result" \
				+ "?activity_filter=18" \
				+ "&venue_filter=" + venue.to_s \
				+ "&day_filter=" + day_filter.to_s \
				+ "&date_filter=" + create_date_filter(date, true) \
				+ "&search=Search");
			header = {
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36",
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Referer" => "https://members.myactivesg.com/auth",
				"Cookie" => set_cookie,
				"Connection" => "keep-alive",
			}
			req = Net::HTTP::Get.new(uri, header)
			res = request(req)
			get_cookie(res)

			@@slot_url = res["Location"]
			uri = URI.parse(@@slot_url)
			header = {
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36",
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Referer" => "https://members.myactivesg.com/auth",
				"Cookie" => set_cookie,
				"Connection" => "keep-alive",
			}
			req = Net::HTTP::Get.new(uri, header)
			res = request(req)
			get_cookie(res)
			@@referer_url = uri.to_s

			write_to_file("tmp/html/result.html", res.body)

			parse_search_result(res.body)
		end

		def parse_search_result(body)
			reg_slot =  /name="timeslots\[\]" id="([\w]+?)" value="(.+?)"/
			available_slots = {}
			body.scan(reg_slot) {|s| available_slots[get_court_key(s[1])] = s[1] }

			reg_action = /id="formTimeslots" action="(.+?)"/
			m = reg_action.match(body)
			return {} if m == nil
			@@booking_url = m[1]

			write_log "Booking URL: #{@@booking_url}"

			reg_oauth = /name="([\w]{32})" value="([\w]{64})"/
			m = reg_oauth.match(body)
			return {} if m == nil
			@@oauth_key = m[1]
			@@oauth_value = m[2]

			available_slots
		end

		def get_court_key(id)
			arr = id.split(';')
			arr[0].gsub("Court ", "") + " - " + arr[3]
		end

		def book_slots(*slots)
			slots.each{ |slot|
				next if slot == nil

				booked = false
				(1..30).each do
					booked = book_single_slot(slot)
					if booked
						puts "#{username} : court [#{slot}] booked :)"
						break
					else 
						puts "#{username} : failed to book [#{slot}]. try again."
						sleep(1)
					end
				end
				if booked == false
					puts "#{username} : court [#{slot}] cannot be booked :("
				end
			}
		end
		def book_single_slot(slot)
			uri = URI.parse(@@booking_url)
			referer_url = 
			header = {
				"Cookie" => set_cookie,
				"Origin" => "https://members.myactivesg.com",
				"Host" => "members.myactivesg.com",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36",
				"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
				"Accept" => "*/*",
				"Referer" => @@referer_url,
				"X-Requested-With" => "XMLHttpRequest",
				"Connection" => "keep-alive",
				"DNT" => "1",
			}
			form_data = {
				"activity_id" => 18,
				"venue_id" => @@venue_id.to_s,
				"chosen_date" => @@date.to_s,
				@@oauth_key => @@oauth_value,
				"timeslots[]" => slot,
				"cart" => "ADD TO CART",
				"fdscv" => "0XX0Z"
			}
			req = Net::HTTP::Post.new(uri.path, header)
			req.set_form_data(form_data)
			res = request(req)
			set_cookie(res) if res != nil

			puts "#{@username} : #{res.body}"

			if res.body[/Bad Request/] != nil
				puts "#{username} : *****ERROR********"
				raise 'Bad Request. Retry'
			end

			res.body[/Your bookings have been saved/] != nil
		end
	end
end