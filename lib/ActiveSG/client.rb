require "net/https"
require "cgi"

module ActiveSG
	class Client
		attr :username, true
		attr :ecpassword, true
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

		@@ua = "Mozilla/5.0"

		def initialize(username, ecpassword, debug = false)
			@username = username
			@ecpassword = ecpassword
			@debug = debug

			uri = URI.parse("https://members.myactivesg.com/auth")
			@@http = Net::HTTP.new(uri.host, uri.port)
			@@http.use_ssl = true
			@@http.verify_mode = OpenSSL::SSL::VERIFY_PEER
		end

		def request(req)
			req["Accept_Endocing"] = "gzip, deflate, sdch"
			res = @@http.request(req)
			get_cookie(res)
			res
		end

		def get_cookie(res)
			return if res == nil

			set_cookie_value = res.get_fields('Set-Cookie')
			return if set_cookie_value == nil
			
			res.get_fields('Set-Cookie').each{ |str|
				k,v = str[0...str.index(';')].split('=')
				@@cookie[k] = v
			}
			@@cookie
		end

		def set_cookie()
			@@cookie.map{ |k,v| "#{k}=#{v}" }.join(';')
		end

		def write_log(msg)
			puts "#{@username} : #{msg}"
		end

		def write_to_file(path, text)
			return if @debug == false
			File.open("tmp/html/" + path, "w") do |file|
				file.write(text)
			end
		end

		# Login
		def login
			auth_page = access_auth_page()
			return submit_login(auth_page)
		end

		def access_auth_page
			uri = URI.parse("https://members.myactivesg.com/auth")
			header = {
				"Accept" => "text/html",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Connection" => "keep-alive",
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"User-Agent" => @@ua
			}

			req = Net::HTTP::Get.new(uri.path, header)
			res = request(req)

			res.body
		end

		def submit_login(auth_page_body)
			uri = URI.parse("https://members.myactivesg.com/auth/signin")
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Cache-Control" => "max-age=0",
				"Connection" => "keep-alive",
				"Content-Type" => "application/x-www-form-urlencoded",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Origin" => "https://members.myactivesg.com",
				"Referer" => "https://members.myactivesg.com/auth",
				"User-Agent" => @@ua
			}

			req = Net::HTTP::Post.new(uri.path, header)
			req.body = "email=" + CGI::escape(@username) + 
				"&ecpassword=" + CGI::escape(@ecpassword) +
				"&_csrf=" + CGI::escape(get_csrf(auth_page_body))
			res = request(req)

			return false, res.body if res["Location"] == "https://members.myactivesg.com/profile"

			uri = URI.parse("https://members.myactivesg.com/profile")
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Cache-Control" => "max-age=0",
				"Connection" => "keep-alive",
				"Content-Type" => "application/x-www-form-urlencoded",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Origin" => "https://members.myactivesg.com",
				"Referer" => "https://members.myactivesg.com/auth/signin",
				"User-Agent" => @@ua
			}
			req = Net::HTTP::Get.new(uri.path, header)
			res = request(req)

			return true, res.body
		end

		# get available slots
		def available_slots_on(date, venue)
			@@venue_id = venue
			@@date = date

			is_quick_book = access_facilities_page

			if is_quick_book
				write_log "Quick booking"
				@@is_quick_booking = true

				slots_by_quick_booking(date, venue)
			else
				write_log "Non-quick booking"
				@@is_quick_booking = false

				slots_by_normal(date, venue)
			end
		end

		def get_csrf(body)
			reg_csrv = /name="_csrf"\s*value="([^"]+)"/
			m = reg_csrv.match(body)
			return "" if m == nil

			m[1]
		end

		def access_facilities_page
			uri = URI.parse("https://members.myactivesg.com/facilities")
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Connection" => "keep-alive",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Referer" => "https://members.myactivesg.com/profile",
				"User-Agent" => @@ua,
			}

			req = Net::HTTP::Get.new(uri.path, header)
			res = request(req)

			res["Location"] == "https://members.myactivesg.com/facilities/quick-booking"
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
			# access quick booking page
			uri = URI.parse("https://members.myactivesg.com/facilities/quick-booking")
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Connection" => "keep-alive",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com", 
				"Referer" => "https://members.myactivesg.com/facilities/quick-booking",
				"User-Agent" => @@ua,
			}
			req = Net::HTTP::Get.new(uri, header)
			res = request(req)

			# retrieve available slots
			uri = URI.parse("https://members.myactivesg.com/facilities/quick-booking")
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Cache-Control" => "max-age=0",
				"Connection" => "keep-alive",
				"Content-Type" => "application/x-www-form-urlencoded",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Origin" => "https://members.myactivesg.com",
				"Referer" => "https://members.myactivesg.com/facilities/profile",
				"User-Agent" => @@ua,
			}
			form_data = {
				"activity_filter" => "18",
				"venue_filter" => venue.to_s,
				"date_filter" => create_date_filter(date, false)
			}
			req = Net::HTTP::Post.new(uri, header)
			req.set_form_data(form_data)
			res = request(req)
			@@referer_url = uri.to_s

			parse_search_result(res.body)
		end

		def access_quick_booking_page
			uri = URI.parse("https://members.myactivesg.com/facilities/quick-booking")
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",	
				"Connection" => "keep-alive",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com", 
				"Referer" => "https://members.myactivesg.com/facilities/quick-booking",
				"User-Agent" => @@ua,
			}
			req = Net::HTTP::Get.new(uri, header)
			res = request(req)
		end

		def slots_by_normal(date, venue)

			@@slot_url, body = retrieve_normal_search_location

			write_to_file("std_booking.html", body)

			uri = URI.parse(@@slot_url)
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Connection" => "keep-alive",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Referer" => "https://members.myactivesg.com/facilities",
				"User-Agent" => @@ua,
			}
			req = Net::HTTP::Get.new(uri, header)
			res = request(req)
			@@referer_url = uri.to_s

			parse_search_result(res.body)
		end

		def retrieve_normal_search_location
			day_filter = @@date.wday
			day_filter = 7 if @@date.wday == 0

			uri = URI.parse("https://members.myactivesg.com/facilities/result" \
				+ "?activity_filter=18" \
				+ "&venue_filter=" + @@venue_id.to_s \
				+ "&day_filter=" + day_filter.to_s \
				+ "&date_filter=" + create_date_filter(@@date, true) \
				+ "&search=Search");
			header = {
				"Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Connection" => "keep-alive",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Referer" => "https://members.myactivesg.com/facilities",
				"User-Agent" => @@ua,
			}
			req = Net::HTTP::Get.new(uri, header)
			res = request(req)
			return res["Location"], res
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

			return available_slots, body
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
					booked = book_single_slot(slot, @@referer_url)
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

		def book_single_slot(slot, referer_url)
			p "referer_url: " + referer_url
			p "oauth_key: " + @@oauth_key
			p "oauth_value: " + @@oauth_value   

			uri = URI.parse(@@booking_url)
			referer_url = 
			header = {
				"Accept" => "*/*",
				"Accept-Language" => "ja,en;q=0.8,zh;q=0.6",
				"Connection" => "keep-alive",
				"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
				"Cookie" => set_cookie,
				"DNT" => "1",
				"Host" => "members.myactivesg.com",
				"Origin" => "https://members.myactivesg.com",
				"User-Agent" => @@ua,
				"Referer" => referer_url,
				"X-Requested-With" => "XMLHttpRequest",
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

			if res.body[/Bad Request/] != nil
				puts "#{username} : *****ERROR********"
				raise 'Bad Request. Retry'
			end

			res.body[/Your bookings have been saved/] != nil
		end
	end
end