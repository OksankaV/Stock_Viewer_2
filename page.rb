# -*- encoding : utf-8 -*-
require 'rubygems'
require 'sinatra'
require 'sqlite3'
require 'json'
require 'cgi'
require 'net/http'
require 'uri'
require 'axlsx'

require_relative 'public/lib/content'

set :protection, :except => :ip_spoofing

admin_data_hash = JSON.parse(IO.read('public/lib/admin.json'))
set :username,admin_data_hash['username']
set :token,admin_data_hash['token']
set :password,admin_data_hash['password']


helpers do
	def admin? ; request.cookies[settings.username] == settings.token ; end
	def protected! ; halt [ 401, 'Not Authorized' ] unless admin? ; end
end


Title = "VSIKOLESA"
Price_table_headers = {'brand' =>'Виробник', 'family' => 'Марка', 'dimensiontype' => 'Типорозмір', 'sidewall' => 'Боковина', 'origin' => 'Країна', 'runflat' => 'Run Flat', 'productiondate' => 'DOT', 'season' => 'Сезон',  'remain' => 'Залишок', 'supplier' => 'Склад', 'suppliercomment' => 'Постачальник', 'rp' => 'Роздрібна ціна', 'bp' => 'Гуртова ціна', 'sp' => 'Вхідна ціна', 'bpvat' => 'Гуртова з ПДВ', 'actualdate' => 'Дата', 'sourcestring' => 'Вхідний рядок'}
Price_table_columns = ['id', 'brand', 'family', 'origin', 'comment', 'remain', 'moreflag', 'supplier', 'sp', 'spc', 'sourcestring', 'minimalorder', 'deliverytyme', 'suppliercomment', 'actualdate', 'runflat', 'sidewall', 'productiondate', 'diameterc', 'application', 'season', 'traileraxle', 'steeringaxle', 'driveaxle', 'dimensiontype', 'sectionsize', 'bp', 'bpvat', 'bppe', 'rp', 'rpvat', 'rppe', 'unknown']
Show_data_field = ['id','brand', 'family', 'dimensiontype', 'sidewall', 'origin', 'runflat', 'productiondate', 'season', 'bp', 'remain', 'supplier', 'rp', 'sp', 'suppliercomment', 'bpvat', 'actualdate', 'sourcestring']
Header_data_field = {'id' => 'Вибрати', 'family' => 'Модель', 'season' => 'Сезон', 'dimensiontype' => 'Типорозмір', 'bp' => 'Гуртова ціна', 'rp' => 'Роздрібна ціна'}
Seasons = ["-", "літо", "зима", "в/c"]
Seasons_images = ["question", "summer", "winter", "all_season"]
Remain = Array.new(10000){ |index| index.to_s}
Orders_table_headers_cut = {'issued' =>'Дата','buyer' =>'Покупець', 'article' => 'Товар', 'amount' => 'К-ть', 'supplier' => 'Склад', 'inprice' => 'Вхідна ціна (1 шт)','rate' => 'Курс', 'outprice' => 'Продажна ціна (1 шт)', 'transfered' => 'Оплачено клієнтом', 'transferprice' => 'Оплачено нами', 'payed_by_buyer' => 'Оплачено клієнтом',  'payed_by_us' => 'Оплачено нами', 'status' => 'Статус', 'bank' => 'Банк', 'sent' => 'Від-ня', 'track_id' => '№ декларації', 'cash_flag' => 'Готівкова операція', 'order_notes' => 'Нотатки замовлення', 'buyer_notes' => 'Нотатки покупця', 'reserve_date' => 'Резерв', 'expected_receive_date' => 'План. от.', 'receive_date' => 'Факт. от.', 'post_name' => 'Трансп. комп.' , 'specification' => 'Уточнення'}
Orders_table_headers = {'issued' =>'Дата','buyer' =>'Покупець', 'article' => 'Товар', 'amount' => 'Кількість', 'supplier' => 'Склад', 'inprice' => 'Вхідна ціна (1 шт)','rate' => 'Курс', 'outprice' => 'Продажна ціна (1 шт)', 'transfered' => 'Оплачено клієнтом', 'transferprice' => 'Оплачено нами', 'payed_by_buyer' => 'Оплачено клієнтом',  'payed_by_us' => 'Оплачено нами', 'status' => 'Статус', 'bank' => 'Банк', 'sent' => 'Відправлення', 'track_id' => '№ декларації', 'cash_flag' => 'Готівкова операція', 'order_notes' => 'Нотатки замовлення', 'buyer_notes' => 'Нотатки покупця', 'reserve_date' => 'Резерв', 'expected_receive_date' => 'Планове отримання', 'receive_date' => 'Фактичне отримання', 'post_name' => 'Транспортна компанія' , 'specification' => 'Уточнення'}
Orders_table_columns = ['id','issued','buyer', 'article', 'amount', 'supplier', 'inprice','rate', 'outprice', 'transfered', 'transferprice', 'payed_by_buyer', 'payed_by_us', 'status', 'bank', 'sent', 'track_id', 'cash_flag', 'notes','post_name', 'specification', 'reserve_date', 'expected_receive_date', 'receive_date']
Buyers_table_columns = ['name','notes', 'fullname', 'telephone', 'city', 'contact_person']
Buyers_table_headers = {'buyer' =>'Скорочена назва', 'fullname' => 'Повна назва', 'telephone' => 'Телефон', 'city' => 'Місто', 'contact_person' => 'Контактна особа', 'notes' => 'Нотатки'}
Status_values_array = ['нове', 'резерв', 'відправлено', 'отримано']

Orders_table_excel_columns = ['buyer', 'fullname', 'telephone', 'city','article','amount', 'supplier', 'sent', 'expected_receive_date','post_name','track_id']

def select_data_from_db()
	if File.exists?("../data/tyre.db")
		$db = SQLite3::Database.new("../data/tyre.db")
		$price_date_check = File.new("../data/tyre.db").mtime
		$price_date = File.new("../data/tyre.db").mtime.localtime("+03:00").strftime("(оновлено %d/%m/%Y)")
	end
	$tyre_size = $db.execute("SELECT DISTINCT sectionsize FROM price ORDER BY sectionsize ASC").flatten
	$tyre_diameter = $db.execute("SELECT DISTINCT diameterc FROM price ORDER BY diameterc ASC").flatten
	$tyre_season = $db.execute("SELECT DISTINCT season FROM price ORDER BY season ASC").flatten
	$tyre_supplier = $db.execute("SELECT DISTINCT supplier FROM price ORDER BY supplier ASC").flatten

	tyre_family_brand_name = $db.execute("SELECT DISTINCT family, brand FROM price")

	tyre_family_brand = {}
	tyre_family_brand_name.each do |brand_family|
		if !tyre_family_brand.has_key?(brand_family.last)
			tyre_family_brand[brand_family.last] = []
		end
		    tyre_family_brand[brand_family.last].push(brand_family.first)
	end
	tyre_family = tyre_family_brand.values.flatten.uniq.sort
	$tyre_brand_name = tyre_family_brand.keys.sort
	$tyre_family_brand_name = tyre_family_brand
	$tyre_family_name = tyre_family
	$tyre_family_brand_name.each_pair do |brand,families|
		$tyre_family_brand_name[brand] = []
		families.each do |one_family|
			$tyre_family_brand_name[brand].push(one_family)
		end
	end 
end

def select_data_from_orders_db()
	if File.exists?("../data/orders.db")
		$db_orders = SQLite3::Database.new("../data/orders.db")
		$db_orders.execute("PRAGMA foreign_keys = ON;")
	end	
end

def select_values(param_select_values,new_param_value,db_array)
    if param_select_values == nil
    	select_array = []
    else
    	if param_select_values != [""]
    		select_array = param_select_values
    	else
    		select_array = []
    	end	
    end
    if new_param_value == nil
    	select_array = []
    else	
		if new_param_value != "" and db_array.include?(new_param_value) and select_array.include?(new_param_value) == false
			select_array.push(new_param_value)
		end
	end	
    return (select_array)
end

def detect_one_select_value(input_value,select_value)
	return_value = ""
	if ((input_value == nil) || (input_value == ""))
		if select_value == nil
			return_value = ""
		else
			if select_value != ""
				return_value = select_value
			else
				return_value = ""
			end	
		end
	else		
		return_value = input_value
	end
	return return_value
end

def filter_select(select, value, check_value, text, hash_key)
    if check_value.include?(value)
		select = select + text
        @bind_hash[hash_key.to_sym] = value
    end  
    return select  
end

def make_href(select_value,param_name,param_array_name)
	if select_value.empty?  
		@table_href += param_name + "="
	else	
		select_value.each do |value|
			@table_href += param_array_name + "=" + CGI::escape(value)
		end
	end	
end

select_data_from_db()

get '/' do
	if (File.new("../data/tyre.db").mtime != $price_date_check)
		select_data_from_db()
	end

    @message = "Для пошуку даних обов'язково введіть параметр Ширина/Висота"
    @message_no_data = "Немає даних, що відповідають вибраним значенням"
    if params[:press_reset_button] == "true"
    	@select_brands = []
		@select_families = []
		@select_sizes = []
		@select_diameters = []
		@select_seasons = []
		@select_suppliers = []
		@select_date = ""
		@select_remain = ""
		@select_start_price = ""
		@select_finish_price = ""
    else	
		@select_brands = select_values(params[:tyre_brand_selected],params[:tyre_brand_typeahead],$tyre_brand_name)
		@select_families = select_values(params[:tyre_family_selected],params[:tyre_family_typeahead],$tyre_family_name)
		@select_sizes = select_values(params[:tyre_size_selected],params[:tyre_size_typeahead],$tyre_size)
		@select_diameters = select_values(params[:tyre_diameter_selected],params[:tyre_diameter_typeahead],$tyre_diameter)
		@select_seasons = select_values(params[:tyre_season_selected],"",$tyre_season)
		@select_suppliers = select_values(params[:tyre_supplier_selected],params[:tyre_supplier_typeahead],$tyre_supplier)

		@select_date = detect_one_select_value(params[:tyre_date_typeahead],params[:tyre_date_selected])
		@select_remain = detect_one_select_value(params[:tyre_remain_typeahead],params[:tyre_remain_selected])
		@select_start_price = detect_one_select_value(params[:tyre_start_price_input],params[:tyre_start_price_selected])
		@select_finish_price = detect_one_select_value(params[:tyre_finish_price_input],params[:tyre_finish_price_selected])

	
	end

	tyre_family_help_array = [] 
    if @select_brands.empty?
		tyre_family_help_array = $tyre_family_name
	else	
		help_array = []
		$tyre_family_brand_name.each_pair do |brand,brand_families|
			if @select_brands.include?(brand)
				brand_families.each do |one_family|
					tyre_family_help_array.push(one_family)
				end	
			end	
		end	
    end
    
    
    @tyre_family_help_array = tyre_family_help_array

	@table_href = ""
	if @select_date.empty?  
		@table_href += "date="
	else	
		@table_href += "date=" + @select_date
	end
	if @select_remain.empty?  
		@table_href += "&remain="
	else	
		@table_href += "&remain=" + @select_remain
	end
	if @select_start_price.empty?  
		@table_href += "&start_price="
	else	
		@table_href += "&start_price=" + @select_start_price
	end
	if @select_finish_price.empty?  
		@table_href += "&finish_price="
	else	
		@table_href += "&finish_price=" + @select_finish_price
	end	
	make_href(@select_brands,"&brand","&brand[]")
	make_href(@select_families,"&family","&family[]")
	make_href(@select_sizes,"&size","&size[]")
	make_href(@select_diameters,"&diameter","&diameter[]")
	make_href(@select_seasons,"&season","&season[]")
	make_href(@select_suppliers,"&supplier","&supplier[]")
	@table_url = @table_href
	@show_table = false
	
	@bind_hash = {}

	if @select_sizes.empty? == false
		if params[:press_submit_button] == "true"
			@press_submit_button = true
			@show_table = true	
			select_string = "select brand, min(rp), max(rp), group_concat(distinct(nullif(origin,''))), count(*) from price where"
			select_string = select_string + " ( "
			i=0
			@select_sizes.each do |tyre_sizes_check|
				if i == 0
					select_string = filter_select(select_string, tyre_sizes_check, $tyre_size, "sectionsize = :size" + i.to_s, "size" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_sizes_check, $tyre_size, " or sectionsize = :size" + i.to_s, "size" + i.to_s)
				end
				i += 1
			end
			select_string =  select_string + " ) "
	
			if @select_brands.empty? == false
				select_string = select_string + " and ( "
				i=0
				@select_brands.each do |tyre_brands_check|
					if i == 0
						select_string = filter_select(select_string, tyre_brands_check, $tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_brands_check, $tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end
			if @select_families.empty? == false
				select_string = select_string + " and ( "
				i=0
				@select_families.each do |tyre_families_check|
					if i == 0
						select_string = filter_select(select_string, tyre_families_check, $tyre_family_name, "family = :family" + i.to_s, "family" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_families_check, $tyre_family_name, " or family = :family" + i.to_s, "family" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end
			if @select_diameters.empty? == false
				select_string = select_string + " and ( "
				i=0
				@select_diameters.each do |tyre_diameters_check|
					if i == 0
						select_string = filter_select(select_string, tyre_diameters_check, $tyre_diameter, "diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_diameters_check, $tyre_diameter, " or diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end
			if @select_seasons.empty? == false
				select_string = select_string + " and ( "
				i=0
				@select_seasons.each do |tyre_seasons_check|
					if i == 0
						select_string = filter_select(select_string, tyre_seasons_check, $tyre_season, "season = :season" + i.to_s, "season" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_seasons_check, $tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
					end
					i += 1
				end
				select_string = filter_select(select_string, "0", $tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
				select_string =  select_string + " ) "
			end
			
			if @select_suppliers.empty? == false
				select_string = select_string + " and ( "
				i=0
				@select_suppliers.each do |tyre_suppliers_check|
					if i == 0
						select_string = filter_select(select_string, tyre_suppliers_check, $tyre_supplier, "supplier = :supplier" + i.to_s, "supplier" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_suppliers_check, $tyre_supplier, " or supplier = :supplier" + i.to_s, "supplier" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end
	
			if @select_remain.empty? == false
				select_string = select_string + " and (remain >= :remain or remain = 0) "
				@bind_hash["remain".to_sym] = @select_remain
			end
			
			if @select_start_price.empty? == false || @select_finish_price.empty? == false
				select_string = select_string + " and ( "
				if @select_start_price != ""
					select_string = select_string + "rp >= :start_price"
					@bind_hash["start_price".to_sym] = @select_start_price
				end
				if (@select_start_price != "" && @select_finish_price != "")
					select_string = select_string + " and "
				end
				if @select_finish_price != ""
					select_string = select_string + "rp <= :finish_price"
					@bind_hash["finish_price".to_sym] = @select_finish_price
				end
				select_string = select_string + " ) "
			end
	
			if @select_date.empty? == false
				select_string = select_string + " and (actualdate >= :date) "
				date = @select_date.scan(/(\d+)\/(\d+)\/(\d+)/).flatten
				@bind_hash["date".to_sym] = Time.gm(date[2],date[1],date[0]).strftime("%Y-%m-%d %H:%M:%S")
			end
	
			select_string = select_string + "GROUP BY brand ORDER BY brand"
			select_brand_price_array = $db.execute(select_string, @bind_hash)
	
			@select_brand_price_hash = {}
			select_brand_price_array.each do |brand_price_array|
				@select_brand_price_hash[brand_price_array.first] = [brand_price_array[1],brand_price_array[2],brand_price_array[3],brand_price_array[4]]
			end
			if @select_brand_price_hash.empty?
				@show_table = false
			end
			@search_primary_btn = ""
			@show_primary_btn = "btn-primary"  
		else
			@message = "Для відображення даних натисніть ПОШУК"
			@search_primary_btn = "btn-primary"
			@show_primary_btn = "" 
		end	
	else 
		@message = "Для пошуку даних обов'язково введіть параметр Ширина/Висота"
		@search_primary_btn = "btn-primary"
		@show_primary_btn = "" 	
	end
	if admin?
		protected!
		#@show_all_columns = true
		@admin_filter_page = true
		erb :filter
	else
		@checked_array = []
		add_to_checked_array(@select_sizes,"size[]")
		add_to_checked_array(@select_brands,"brand[]")
		add_to_checked_array(@select_families,"family[]")
		add_to_checked_array(@select_diameters,"diameter[]")
		add_to_checked_array(@select_suppliers,"supplier[]")
		add_to_checked_array(@select_seasons,"season[]")
		if @select_date.empty? == false
			hash = {}
			hash['name'] = "date"
			hash['value'] = @select_date
			@checked_array.push(hash)
		end	
		if @select_remain.empty? == false
			hash = {}
			hash['name'] = "remain"
			hash['value'] = @select_remain
			@checked_array.push(hash)
		end
		if @select_start_price.empty? == false
			hash = {}
			hash['name'] = "start_price"
			hash['value'] = @select_start_price
			@checked_array.push(hash)
		end
		if @select_finish_price.empty? == false
			hash = {}
			hash['name'] = "finish_price"
			hash['value'] = @select_finish_price
			@checked_array.push(hash)
		end
		@admin_filter_page = false
		erb :filter
	end 
	

end

get '/table' do
	@bind_hash = {}	
	select_brands = params[:brand]
	select_brands = "" if select_brands == nil 		
    select_families = params[:family]
    select_families = "" if select_families == nil 
    select_sizes = params[:size]
    select_diameters = params[:diameter]
    select_diameters = "" if select_diameters == nil 
    select_suppliers = params[:supplier]
    select_suppliers = "" if select_suppliers == nil 
    select_seasons = params[:season]
    select_seasons = "" if select_seasons == nil 
    select_date = params[:date]
    select_date = "" if select_date == nil 
    select_remain = params[:remain]
    select_remain = "" if select_remain == nil
    select_start_price = params[:start_price]
    select_start_price = "" if select_start_price == nil
    select_finish_price = params[:finish_price]
    select_finish_price = "" if select_finish_price == nil 
    
    select_string = "select * from price where"
	select_string = select_string + " ( "
	i=0
	select_sizes.each do |tyre_sizes_check|
		if i == 0
			select_string = filter_select(select_string, tyre_sizes_check, $tyre_size, "sectionsize = :size" + i.to_s, "size" + i.to_s)
		else
			select_string = filter_select(select_string, tyre_sizes_check, $tyre_size, " or sectionsize = :size" + i.to_s, "size" + i.to_s)
		end
		i += 1
	end
	select_string =  select_string + " ) "
	
	if select_brands.empty? == false
		select_string = select_string + " and ( "
		i=0
		select_brands.each do |tyre_brands_check|
			if i == 0
				select_string = filter_select(select_string, tyre_brands_check, $tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_brands_check, $tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
			end
			i += 1
		end
		select_string =  select_string + " ) "
	end
	if select_families.empty? == false
		select_string = select_string + " and ( "
		i=0
		select_families.each do |tyre_families_check|
			if i == 0
				select_string = filter_select(select_string, tyre_families_check, $tyre_family_name, "family = :family" + i.to_s, "family" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_families_check, $tyre_family_name, " or family = :family" + i.to_s, "family" + i.to_s)
			end
			i += 1
		end
		select_string =  select_string + " ) "
	end
	if select_diameters.empty? == false
		select_string = select_string + " and ( "
		i=0
		select_diameters.each do |tyre_diameters_check|
			if i == 0
				select_string = filter_select(select_string, tyre_diameters_check, $tyre_diameter, "diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_diameters_check, $tyre_diameter, " or diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
			end
			i += 1
		end
		select_string =  select_string + " ) "
	end
	if select_suppliers.empty? == false
		select_string = select_string + " and ( "
		i=0
		select_suppliers.each do |tyre_suppliers_check|
			if i == 0
				select_string = filter_select(select_string, tyre_suppliers_check, $tyre_supplier, "supplier = :supplier" + i.to_s, "supplier" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_suppliers_check, $tyre_supplier, " or supplierc = :supplier" + i.to_s, "supplier" + i.to_s)
			end
			i += 1
		end
		select_string =  select_string + " ) "
	end
	if select_seasons.empty? == false
		select_string = select_string + " and ( "
		i=0
		select_seasons.each do |tyre_seasons_check|
			if i == 0
				select_string = filter_select(select_string, tyre_seasons_check, $tyre_season, "season = :season" + i.to_s, "season" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_seasons_check, $tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
			end
			i += 1
		end
		select_string = filter_select(select_string, "0", $tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
		select_string =  select_string + " ) "
	end
	
	if select_remain.empty? == false
		select_string = select_string + " and (remain >= :remain or remain = 0) "
		@bind_hash["remain".to_sym] = select_remain
	end
	
	if select_start_price.empty? == false || select_finish_price.empty? == false
		select_string = select_string + " and ( "
		if select_start_price != ""
			select_string = select_string + "rp >= :start_price"
			@bind_hash["start_price".to_sym] = select_start_price
		end
		if (select_start_price != "" && select_finish_price != "")
			select_string = select_string + " and "
		end
		if select_finish_price != ""
			select_string = select_string + "rp <= :finish_price"
			@bind_hash["finish_price".to_sym] = select_finish_price
		end
		select_string = select_string + " ) "
	end

	
	if select_date.empty? == false
		select_string = select_string + " and (actualdate >= :date) "
		date = select_date.scan(/(\d+)\/(\d+)\/(\d+)/).flatten
		@bind_hash["date".to_sym] = Time.gm(date[2],date[1],date[0]).strftime("%Y-%m-%d %H:%M:%S")
	end
	
	all_data_array = []
	show_data_array = []
	select_all_data = $db.execute(select_string, @bind_hash)
	select_all_data.each do |one_row_data|
		data_hash = {}
		show_data_hash = {}
		one_row_data.each_index do |index|
			data_hash[Price_table_columns[index]] = one_row_data[index]
			if Header_data_field.has_key?(Price_table_columns[index])
				show_data_hash[Price_table_columns[index]] = one_row_data[index]
			end
		end
		all_data_array.push(data_hash)
		show_data_array.push(show_data_hash)
	end
		
	show_data_array.each_index do |show_data_array_index|
		data_hash = show_data_array.at(show_data_array_index)
		data_hash.each_pair do |data_hash_key, data_hash_value|
			if data_hash_value.class == Float	
	  			show_data_array[show_data_array_index][data_hash_key] = data_hash_value.round(2)
	  		end			 	
	  		if data_hash_key == 'season' 
	  			show_data_array[show_data_array_index][data_hash_key] = Seasons[data_hash_value.to_i]
	  		end	
	  		if (data_hash_key == 'sp') and (show_data_array[show_data_array_index]['sp'] != 0 or show_data_array[show_data_array_index]['sp'] != "невідомо")
	  			if data_hash['spc'] == "1"
	  				show_data_array[show_data_array_index][data_hash_key] = show_data_array[show_data_array_index][data_hash_key].ceil.to_s + " грн."
	  			elsif  data_hash['spc'] == "2"
	 				show_data_array[show_data_array_index][data_hash_key] = (show_data_array[show_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " $"
	  			elsif  data_hash['spc'] == "3"
	  				show_data_array[show_data_array_index][data_hash_key] = (show_data_array[show_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " &euro;"
	  			elsif  data_hash['spc'] == "4"
	  				show_data_array[show_data_array_index][data_hash_key] = (show_data_array[show_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " PLN"
	  			end
	  		end
	  		if (data_hash_key == 'sp') and (show_data_array[show_data_array_index]['sp'] == 0 or show_data_array[show_data_array_index]['sp'] == "невідомо")
	  			show_data_array[show_data_array_index][data_hash_key] = "невідомо"	
	  		end

		  	if (data_hash_key == 'bp' or data_hash_key == 'bpvat' or data_hash_key == 'rpvat' or data_hash_key == 'rppe' or data_hash_key == 'rp') and (show_data_array[show_data_array_index]['sp'] != 0 or show_data_array[show_data_array_index]['sp'] != "невідомо")
		  		show_data_array[show_data_array_index][data_hash_key ] = show_data_array[show_data_array_index][data_hash_key ].ceil.to_s + " грн."
		  	end
		  	if (data_hash_key == 'bp' or data_hash_key == 'bpvat' or data_hash_key == 'rpvat' or data_hash_key == 'rppe' or data_hash_key == 'rp') and (show_data_array[show_data_array_index]['sp'] == 0 or show_data_array[show_data_array_index]['sp'] == "невідомо")
	  			show_data_array[show_data_array_index][data_hash_key] = "невідомо"		
		  	end  		
		end
	end
	
		
	return (JSON.pretty_generate(show_data_array))

end

def add_to_checked_array(param_array,param_name)
	param_array.each do |value|
		hash = {}
		hash['name'] = param_name
		hash['value'] = value
		@checked_array.push(hash)
	end
end	

post '/selected_items' do
	select_brands = params[:brand]
	select_brands = [] if select_brands == nil 		
    select_families = params[:family]
    select_families = [] if select_families == nil 
    select_sizes = params[:size]
    select_diameters = params[:diameter]
    select_diameters = [] if select_diameters == nil
    select_suppliers = params[:supplier]
    select_suppliers = [] if select_suppliers == nil 
    select_seasons = params[:season]
    select_seasons = [] if select_seasons == nil 
    select_date = params[:date]
    select_date = "" if select_date == nil 
    select_remain = params[:remain]
    select_remain = "" if select_remain == nil
    select_start_price = params[:start_price]
    select_start_price = "" if select_start_price == nil
    select_finish_price = params[:finish_price]
    select_finish_price = "" if select_finish_price == nil 

	@show_table = true
	checked_id_array = params[:checked_id]
	checked_id_array = [] if checked_id_array == nil
		
	checked_brand_array = params[:checked_brand]
	checked_brand_array = [] if checked_brand_array == nil
	if checked_id_array.empty? and checked_brand_array.empty?
		@show_table = false
	end	
	@checked_array = []
	add_to_checked_array(checked_id_array,"checked_id[]")
	add_to_checked_array(checked_brand_array,"checked_brand[]")
	add_to_checked_array(select_sizes,"size[]")
	add_to_checked_array(select_brands,"brand[]")
	add_to_checked_array(select_families,"family[]")
	add_to_checked_array(select_diameters,"diameter[]")
	add_to_checked_array(select_suppliers,"supplier[]")
	add_to_checked_array(select_seasons,"season[]")
	if select_date.empty? == false
		hash = {}
		hash['name'] = "date"
		hash['value'] = select_date
		@checked_array.push(hash)
	end	
	if select_remain.empty? == false
		hash = {}
		hash['name'] = "remain"
		hash['value'] = select_remain
		@checked_array.push(hash)
	end
	if select_start_price.empty? == false
		hash = {}
		hash['name'] = "start_price"
		hash['value'] = select_start_price
		@checked_array.push(hash)
	end
	if select_finish_price.empty? == false
		hash = {}
		hash['name'] = "finish_price"
		hash['value'] = select_finish_price
		@checked_array.push(hash)
	end
	@message = "Ви не вибрали жодного елементу"
	
	if admin?
		protected!
		@admin_select_items_page = true
		erb :selected_items
	else
		@admin_select_items_page = false
		erb :selected_items
	end 
	
end

post '/table_selected_items' do
 	select_brands = params[:brand]
	select_brands = [] if select_brands == nil 	
    select_families = params[:family]
    select_families = [] if select_families == nil 
    select_sizes = params[:size]
    select_diameters = params[:diameter]
    select_diameters = [] if select_diameters == nil
    select_suppliers = params[:supplier]
    select_suppliers = [] if select_suppliers == nil 
    select_seasons = params[:season]
    select_seasons = [] if select_seasons == nil 
    select_date = params[:date]
    select_date = "" if select_date == nil 
    select_remain = params[:remain]
    select_remain = "" if select_remain == nil 
    select_start_price = params[:start_price]
    select_start_price = "" if select_start_price == nil
    select_finish_price = params[:finish_price]
    select_finish_price = "" if select_finish_price == nil 

	@checked_id_array = params[:checked_id]
	@checked_id_array = [] if @checked_id_array == nil 	
	@checked_brand_array = params[:checked_brand]
	@checked_brand_array = [] if @checked_brand_array == nil
	@bind_hash = {}

    sortname_column = params[:sortname]
    rp_number = params[:rp]
    page_number = params[:page]
    sortorder_value = params[:sortorder]
    
    select_string = "select * from price where"
    
    if (@checked_brand_array.empty? == false && admin?) || (@checked_brand_array.empty? && admin? == false)

    if select_sizes.empty? == false
    	select_string = select_string + " ( "
		i=0
		select_sizes.each do |tyre_sizes_check|
			if i == 0
				select_string = filter_select(select_string, tyre_sizes_check, $tyre_size, "sectionsize = :size" + i.to_s, "size" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_sizes_check, $tyre_size, " or sectionsize = :size" + i.to_s, "size" + i.to_s)
			end
			i += 1
		end
		select_string =  select_string + " ) "
	
		if select_families.empty? == false
			select_string = select_string + " and ( "
			i=0
			select_families.each do |tyre_families_check|
				if i == 0
					select_string = filter_select(select_string, tyre_families_check, $tyre_family_name, "family = :family" + i.to_s, "family" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_families_check, $tyre_family_name, " or family = :family" + i.to_s, "family" + i.to_s)
				end
				i += 1
			end
			select_string =  select_string + " ) "
		end
		if select_diameters.empty? == false
			select_string = select_string + " and ( "
			i=0
			select_diameters.each do |tyre_diameters_check|
				if i == 0
					select_string = filter_select(select_string, tyre_diameters_check, $tyre_diameter, "diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_diameters_check, $tyre_diameter, " or diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
				end
				i += 1
			end
			select_string =  select_string + " ) "
		end
		if select_suppliers.empty? == false
			select_string = select_string + " and ( "
			i=0
			select_suppliers.each do |tyre_suppliers_check|
				if i == 0
					select_string = filter_select(select_string, tyre_suppliers_check, $tyre_supplier, "supplier = :supplier" + i.to_s, "supplier" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_suppliers_check, $tyre_supplier, " or supplier = :supplier" + i.to_s, "supplier" + i.to_s)
				end
				i += 1
			end
			select_string =  select_string + " ) "
		end
		if select_seasons.empty? == false
			select_string = select_string + " and ( "
			i=0
			select_seasons.each do |tyre_seasons_check|
				if i == 0
					select_string = filter_select(select_string, tyre_seasons_check, $tyre_season, "season = :season" + i.to_s, "season" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_seasons_check, $tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
				end
				i += 1
			end
			select_string = filter_select(select_string, "0", $tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
			select_string =  select_string + " ) "
		end
	
		if select_remain.empty? == false
			select_string = select_string + " and (remain >= :remain or remain = 0) "
			@bind_hash["remain".to_sym] = select_remain
		end
		
		if select_start_price.empty? == false || select_finish_price.empty? == false
			select_string = select_string + " and ( "
			if select_start_price != ""
				select_string = select_string + "rp >= :start_price"
				@bind_hash["start_price".to_sym] = select_start_price
			end
			if (select_start_price != "" && select_finish_price != "")
				select_string = select_string + " and "
			end
			if select_finish_price != ""
				select_string = select_string + "rp <= :finish_price"
				@bind_hash["finish_price".to_sym] = select_finish_price
			end
			select_string = select_string + " ) "
		end

	
		if select_date.empty? == false
			select_string = select_string + " and (actualdate >= :date) "
			date = select_date.scan(/(\d+)\/(\d+)\/(\d+)/).flatten
			@bind_hash["date".to_sym] = Time.gm(date[2],date[1],date[0]).strftime("%Y-%m-%d %H:%M:%S")
		end
    	
    	if admin?
			select_string = select_string + " and ( "
			i = 0
			@checked_brand_array.each do |checked_brand|
				if i == 0
					select_string = filter_select(select_string, checked_brand, $tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
				else
					select_string = filter_select(select_string, checked_brand, $tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
				end
				i += 1
			end
			select_string =  select_string + " ) "
		else
			if select_brands.empty? == false
				select_string = select_string + " and ( "
				i = 0
				select_brands.each do |select_brand|
					if i == 0
						select_string = filter_select(select_string, select_brand, $tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
					else
						select_string = filter_select(select_string, select_brand, $tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end		
		end	
	end
	end
    
    if admin?
    	protected!

		if @checked_id_array.empty? == false
			if @checked_brand_array.empty? == false
				select_string = select_string + " or ( "
			else
				select_string = select_string + " ( "
			end
			i = 0
			@checked_id_array.each do |checked_id|
				if i == 0
					@bind_hash[("id" + i.to_s).to_sym] = checked_id
					select_string = select_string + "id = :id" + i.to_s
				else
					@bind_hash[("id" + i.to_s).to_sym] = checked_id
						select_string = select_string + " or id = :id" + i.to_s
				end
				i += 1
			end
			select_string =  select_string + " ) "
		end
	end

	select_count = select_string.gsub(/\*/,"count(*)")
	rows_count = $db.execute(select_count, @bind_hash).flatten
	@select_string_to_excel = select_string
	offset_value = page_number.to_i * rp_number.to_i - rp_number.to_i
	select_string = select_string + " order by " + sortname_column + " " + sortorder_value + " limit " + rp_number + " offset " + offset_value.to_s	
		
	all_data_array = []
	select_all_data = $db.execute(select_string, @bind_hash)
	select_all_data.each do |one_row_data|
		data_hash = {}
		one_row_data.each_index do |index|
			data_hash[Price_table_columns[index]] = one_row_data[index]
		end
		all_data_array.push(data_hash)
	end
		
	all_data_array.each_index do |all_data_array_index|
		data_hash = all_data_array.at(all_data_array_index)
		data_hash.each_pair do |data_hash_key, data_hash_value|
			if data_hash_value.class == Float	
	  			all_data_array[all_data_array_index][data_hash_key] = data_hash_value.round(2)
	  		end		
	  		if data_hash_key == 'moreflag' and data_hash_value == 1 
	  			all_data_array[all_data_array_index]['remain'] = ">" + all_data_array[all_data_array_index]['remain'].to_s
	  		end	 	
	  		if data_hash_key == 'runflat'
	  			if data_hash_value == 1
	  				all_data_array[all_data_array_index][data_hash_key] = "Так"
	  			else
	  				all_data_array[all_data_array_index][data_hash_key] = "Ні"	
	  			end	
	  		end
	  		if data_hash_key == 'season' 
	  			all_data_array[all_data_array_index][data_hash_key] = Seasons[data_hash_value.to_i]
	  		end	
	  		if (data_hash_key == 'sp') and (all_data_array[all_data_array_index]['sp'] != 0 or all_data_array[all_data_array_index]['sp'] != "невідомо")
	  			if data_hash['spc'] == "1"
	  				all_data_array[all_data_array_index][data_hash_key] = all_data_array[all_data_array_index][data_hash_key].ceil.to_s + " грн."
	  			elsif  data_hash['spc'] == "2"
	 				all_data_array[all_data_array_index][data_hash_key] = (all_data_array[all_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " $"
	  			elsif  data_hash['spc'] == "3"
	  				all_data_array[all_data_array_index][data_hash_key] = (all_data_array[all_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " &euro;"
	  			elsif  data_hash['spc'] == "4"
	  				all_data_array[all_data_array_index][data_hash_key] = (all_data_array[all_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " PLN"
	  			end
	  		end
	  		if (data_hash_key == 'sp') and (all_data_array[all_data_array_index]['sp'] == 0 or all_data_array[all_data_array_index]['sp'] == "невідомо")
	  			all_data_array[all_data_array_index][data_hash_key] = "невідомо"	
	  		end
	  		if data_hash_key == 'productiondate'
	  			if data_hash_value == nil
	  				all_data_array[all_data_array_index][data_hash_key] = ""
	  			else
		  		production_date = all_data_array[all_data_array_index][data_hash_key].scan(/\d{2}(\d{2})\s+(\d{2})/).flatten
		  		all_data_array[all_data_array_index][data_hash_key] = production_date[1].to_s + production_date[0].to_s
		  		end
		  	end
	  		if data_hash_key == 'actualdate'
		  		data_date = all_data_array[all_data_array_index][data_hash_key].scan(/(\d+)[-|\s+]/).flatten
		  		all_data_array[all_data_array_index][data_hash_key] = data_date[2].to_s + "/" + data_date[1].to_s + "/" + data_date[0].to_s
		  	end
		  	if (data_hash_key == 'bp' or data_hash_key == 'bpvat' or data_hash_key == 'rpvat' or data_hash_key == 'rppe' or data_hash_key == 'rp') and (all_data_array[all_data_array_index]['sp'] != 0 or all_data_array[all_data_array_index]['sp'] != "невідомо")
		  		all_data_array[all_data_array_index][data_hash_key ] = all_data_array[all_data_array_index][data_hash_key ].ceil.to_s + " грн."
		  	end
		  	if (data_hash_key == 'bp' or data_hash_key == 'bpvat' or data_hash_key == 'rpvat' or data_hash_key == 'rppe' or data_hash_key == 'rp') and (all_data_array[all_data_array_index]['sp'] == 0 or all_data_array[all_data_array_index]['sp'] == "невідомо")
	  			all_data_array[all_data_array_index][data_hash_key] = "невідомо"		
		  	end  		
		end
	end
	
	select_data = {}
	rows_array = []

	all_data_array.each do |value_hash|
		rows_array.push({"id" => value_hash["id"], "cell" => value_hash})
	end
    
	select_data["page"] = page_number
	select_data["total"] = rows_count.first
	select_data["rows"] = rows_array
	select_data["post"] = []

	return (JSON.pretty_generate(select_data))
end




get '/models' do
    @families = {}
    if params[:tyre_brand] == nil
        tyre_brands = $tyre_brand_name
    elsif params[:tyre_brand].empty? 
    	tyre_brands = $tyre_brand_name
    else	
    	tyre_brands = params[:tyre_brand]
    end
    tyre_brands.each do |tyre_brand|
        @families[tyre_brand] = $db.execute("SELECT family,brand FROM price WHERE brand=?", tyre_brand).flatten
    end	
    @bind_hash = {}
    
    select_family = "SELECT family FROM price WHERE "
	i=0
	tyre_brands.each do |tyre_brand|
		if i == 0
			select_family = filter_select(select_family, tyre_brand, Tyre_brand, "brand = :brand" + i.to_s, "brand" + i.to_s)
		else
			select_family = filter_select(select_family, tyre_brand, Tyre_brand, " or brand = :brand" + i.to_s, "brand" + i.to_s)
		end
		i += 1
	end
	select_family =  select_string + " ) "
	
    families_brands = $db.execute(select_family, @bind_hash)
   
    
    erb :models
end


get '/login_form' do
	if params[:error] == "true"
		@message_incorect = true
	else
		@message_incorect = false
	end
	erb :login_form 
end 

post '/login' do
	if params['username'] == settings.username && params['password'] == settings.password
		response.set_cookie(settings.username,settings.token) 
		redirect '/'
	else
		redirect '/login_form?error=true'
	end
end

get('/logout'){ response.set_cookie(settings.username, false) ; redirect '/' }


post '/excel_file' do
	@bind_hash = {}
	select_params = JSON.parse(params[:excel_button_all])
	advanced_excel_print = params[:advanced_excel_print]
	select_row_id_array = params[:excel_button_selected].gsub(/row/,"").split(',')
	if select_row_id_array == []
		checked_brands = []
		checked_ids = []
		select_sizes = []
		select_brands = []
		select_families = []
		select_diameters = []
		select_suppliers = []
		select_seasons = []
		select_remain = ''
		select_date = ''
		select_params.each do |hash|
			if hash["name"] == "checked_brand[]"
				checked_brands.push(hash["value"])
			end
			if hash["name"] == "checked_id[]"
				checked_ids.push(hash["value"])
			end
			if hash["name"] == "brand[]"
				select_brands.push(hash["value"])
			end
			if hash["name"] == "size[]"
				select_sizes.push(hash["value"])
			end
			if hash["name"] == "family[]"
				select_families.push(hash["value"])
			end
			if hash["name"] == "diameter[]"
				select_diameters.push(hash["value"])
			end
			if hash["name"] == "supplier[]"
				select_suppliers.push(hash["value"])
			end
			if hash["name"] == "season[]"
				select_seasons.push(hash["value"])
			end
			if hash["name"] == "remain"
				select_remian = hash["value"]
			end
			if hash["name"] == "date"
				select_date = hash["value"]
			end	
		end

		select_string = "select * from price where"
		if (checked_brands.empty? == false && admin?) || (checked_brands.empty? && admin? == false)
		if select_sizes.empty? == false
			select_string = select_string + " ( "
			i=0
			select_sizes.each do |tyre_sizes_check|
				if i == 0
					select_string = filter_select(select_string, tyre_sizes_check, $tyre_size, "sectionsize = :size" + i.to_s, "size" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_sizes_check, $tyre_size, " or sectionsize = :size" + i.to_s, "size" + i.to_s)
				end
				i += 1
			end
			select_string =  select_string + " ) "
	
			if select_families.empty? == false
				select_string = select_string + " and ( "
				i=0
				select_families.each do |tyre_families_check|
					if i == 0
						select_string = filter_select(select_string, tyre_families_check, $tyre_family_name, "family = :family" + i.to_s, "family" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_families_check, $tyre_family_name, " or family = :family" + i.to_s, "family" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end
			if select_diameters.empty? == false
				select_string = select_string + " and ( "
				i=0
				select_diameters.each do |tyre_diameters_check|
					if i == 0
						select_string = filter_select(select_string, tyre_diameters_check, $tyre_diameter, "diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_diameters_check, $tyre_diameter, " or diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end
			if select_suppliers.empty? == false
				select_string = select_string + " and ( "
				i=0
				select_suppliers.each do |tyre_suppliers_check|
					if i == 0
						select_string = filter_select(select_string, tyre_suppliers_check, $tyre_supplier, "supplier = :supplier" + i.to_s, "supplier" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_suppliers_check, $tyre_supplier, " or supplier = :supplier" + i.to_s, "supplier" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end
			if select_seasons.empty? == false
				select_string = select_string + " and ( "
				i=0
				select_seasons.each do |tyre_seasons_check|
					if i == 0
						select_string = filter_select(select_string, tyre_seasons_check, $tyre_season, "season = :season" + i.to_s, "season" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_seasons_check, $tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
					end
					i += 1
				end
				select_string = filter_select(select_string, "0", $tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
				select_string =  select_string + " ) "
			end
	
			if select_remain.empty? == false
				select_string = select_string + " and (remain >= :remain or remain = 0) "
				@bind_hash["remain".to_sym] = select_remain
			end

	
			if select_date.empty? == false
				select_string = select_string + " and (actualdate >= :date) "
				date = select_date.scan(/(\d+)\/(\d+)\/(\d+)/).flatten
				@bind_hash["date".to_sym] = Time.gm(date[2],date[1],date[0]).strftime("%Y-%m-%d %H:%M:%S")
			end
			
			if admin?
				select_string = select_string + " and ( "
				i = 0
				checked_brands.each do |checked_brand|
					if i == 0
						select_string = filter_select(select_string, checked_brand, $tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
					else
						select_string = filter_select(select_string, checked_brand, $tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			else
				if select_brands.empty? == false
					select_string = select_string + " and ( "
					i = 0
					select_brands.each do |select_brand|
						if i == 0
							select_string = filter_select(select_string, select_brand, $tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
						else
							select_string = filter_select(select_string, select_brand, $tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
						end
						i += 1
					end
					select_string =  select_string + " ) "
				end		
			end	
		end
			
		if checked_ids.empty? == false
			if checked_brands.empty? == false
				select_string = select_string + " or ( "
			else
				select_string = select_string + " ( "
			end
			i = 0
			checked_ids.each do |checked_id|
				if i == 0
					@bind_hash[("id" + i.to_s).to_sym] = checked_id
					select_string = select_string + "id = :id" + i.to_s
				else
					@bind_hash[("id" + i.to_s).to_sym] = checked_id
					select_string = select_string + " or id = :id" + i.to_s
				end
				i += 1
			end
			select_string =  select_string + " ) "
		end
		end
	else
		select_string = "select * from price where ("
		i = 0
			select_row_id_array.each do |row_id|
				if i == 0
					@bind_hash[("id" + i.to_s).to_sym] = row_id.to_i
					select_string = select_string + "id = :id" + i.to_s
				else
					@bind_hash[("id" + i.to_s).to_sym] = row_id.to_i
					select_string = select_string + " or id = :id" + i.to_s
				end
				i += 1
			end
		select_string =  select_string + " ) "	
	end
			

	all_data_array = []
	select_all_data = $db.execute(select_string, @bind_hash)
	select_all_data.each do |one_row_data|
		data_hash = {}
		one_row_data.each_index do |index|
			data_hash[Price_table_columns[index]] = one_row_data[index]
		end
		all_data_array.push(data_hash)
	end
		
	all_data_array.each_index do |all_data_array_index|
		data_hash = all_data_array.at(all_data_array_index)
		data_hash.each_pair do |data_hash_key, data_hash_value|
			if data_hash_value.class == Float	
	  			all_data_array[all_data_array_index][data_hash_key] = data_hash_value.round(2)
	  		end		
	  		if data_hash_key == 'moreflag' and data_hash_value == 1 
	  			all_data_array[all_data_array_index]['remain'] = ">" + all_data_array[all_data_array_index]['remain'].to_s
	  		end	 	
	  		if data_hash_key == 'runflat'
	  			if data_hash_value == 1
	  				all_data_array[all_data_array_index][data_hash_key] = "Так"
	  			else
	  				all_data_array[all_data_array_index][data_hash_key] = "Ні"	
	  			end	
	  		end
	  		if data_hash_key == 'season' 
	  			all_data_array[all_data_array_index][data_hash_key] = Seasons[data_hash_value.to_i]
	  		end	
	  		if (data_hash_key == 'sp') and (all_data_array[all_data_array_index]['sp'] != 0 or all_data_array[all_data_array_index]['sp'] != "невідомо")
	  			if data_hash['spc'] == "1"
	  				all_data_array[all_data_array_index][data_hash_key] = all_data_array[all_data_array_index][data_hash_key].ceil.to_s + " грн."
	  			elsif  data_hash['spc'] == "2"
	 				all_data_array[all_data_array_index][data_hash_key] = (all_data_array[all_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " $"
	  			elsif  data_hash['spc'] == "3"
	  				all_data_array[all_data_array_index][data_hash_key] = (all_data_array[all_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " &euro;"
	  			elsif  data_hash['spc'] == "4"
	  				all_data_array[all_data_array_index][data_hash_key] = (all_data_array[all_data_array_index][data_hash_key] + 0.0499999).round(1).to_s + " PLN"
	  			end
	  		end
	  		if (data_hash_key == 'sp') and (all_data_array[all_data_array_index]['sp'] == 0 or all_data_array[all_data_array_index]['sp'] == "невідомо")
	  			all_data_array[all_data_array_index][data_hash_key] = "невідомо"	
	  		end
	  		if data_hash_key == 'productiondate'
	  			if data_hash_value == nil
	  				all_data_array[all_data_array_index][data_hash_key] = ""
	  			else
		  		production_date = all_data_array[all_data_array_index][data_hash_key].scan(/\d{2}(\d{2})\s+(\d{2})/).flatten
		  		all_data_array[all_data_array_index][data_hash_key] = production_date[1].to_s + production_date[0].to_s
		  		end
		  	end
	  		if data_hash_key == 'actualdate'
		  		data_date = all_data_array[all_data_array_index][data_hash_key].scan(/(\d+)[-|\s+]/).flatten
		  		all_data_array[all_data_array_index][data_hash_key] = data_date[2].to_s + "/" + data_date[1].to_s + "/" + data_date[0].to_s
		  	end
		  	if (data_hash_key == 'bp' or data_hash_key == 'bpvat' or data_hash_key == 'rpvat' or data_hash_key == 'rppe' or data_hash_key == 'rp') and (all_data_array[all_data_array_index]['sp'] != 0 or all_data_array[all_data_array_index]['sp'] != "невідомо")
		  		all_data_array[all_data_array_index][data_hash_key ] = all_data_array[all_data_array_index][data_hash_key ].ceil.to_s + " грн."
		  	end
		  	if (data_hash_key == 'bp' or data_hash_key == 'bpvat' or data_hash_key == 'rpvat' or data_hash_key == 'rppe' or data_hash_key == 'rp') and (all_data_array[all_data_array_index]['sp'] == 0 or all_data_array[all_data_array_index]['sp'] == "невідомо")
	  			all_data_array[all_data_array_index][data_hash_key] = "невідомо"		
		  	end  		
		end
	end
	

	temp = Tempfile.new("vsikolesa.xls")
	xls_file = Axlsx::Package.new
	xls_file.workbook do |wb|
	  # define your regular styles
	  styles = wb.styles
	  header = styles.add_style(:bg_color => '00CCFF', :b => true, :border => { :style => :thin, :color => "00" }, :alignment => { :horizontal => :center, :vertical => :center , :wrap_text => true})
	  default = styles.add_style(:border => { :style => :thin, :color => "00" }, :alignment => { :horizontal => :left, :vertical => :center , :wrap_text => true})

	  wb.add_worksheet(:name => 'price') do  |ws|
		if admin?
			protected!
			if advanced_excel_print == "true"
				ws.add_row [Price_table_headers['brand'], Price_table_headers['family'], Price_table_headers['dimensiontype'], Price_table_headers['sidewall'], Price_table_headers['origin'], Price_table_headers['runflat'], Price_table_headers['productiondate'], Price_table_headers['season'], Price_table_headers['remain'], Price_table_headers['supplier'], Price_table_headers['suppliercomment'], Price_table_headers['rp'], Price_table_headers['bp'], Price_table_headers['sp'], Price_table_headers['bpvat'], Price_table_headers['actualdate'], Price_table_headers['sourcestring']], :style => header
				all_data_array.each do |row_hash|
					ws.add_row [row_hash['brand'], row_hash['family'], row_hash['dimensiontype'], row_hash['sidewall'], row_hash['origin'], row_hash['runflat'], row_hash['productiondate'], row_hash['season'], row_hash['remain'], row_hash['supplier'], row_hash['suppliercomment'], row_hash['rp'], row_hash['bp'], row_hash['sp'], row_hash['bpvat'], row_hash['actualdate'], row_hash['sourcestring']], :style => default  
				end
			else
				ws.add_row [Price_table_headers['brand'], Price_table_headers['family'], Price_table_headers['dimensiontype'], Price_table_headers['origin'], Price_table_headers['productiondate'], Price_table_headers['season'], Price_table_headers['remain'],Price_table_headers['suppliercomment'], Price_table_headers['rp'], Price_table_headers['actualdate']], :style => header
				all_data_array.each do |row_hash|
					ws.add_row [row_hash['brand'], row_hash['family'], row_hash['dimensiontype'], row_hash['origin'], row_hash['productiondate'], row_hash['season'], row_hash['remain'],row_hash['suppliercomment'], row_hash['rp'], row_hash['actualdate']], :style => default 
				end	
			end	
		else
			ws.add_row [Price_table_headers['brand'], Price_table_headers['family'], Price_table_headers['dimensiontype'], Price_table_headers['origin'], Price_table_headers['productiondate'], Price_table_headers['season'], Price_table_headers['remain'],Price_table_headers['suppliercomment'], Price_table_headers['rp'], Price_table_headers['actualdate']], :style => header
			all_data_array.each do |row_hash|
				ws.add_row [row_hash['brand'], row_hash['family'], row_hash['dimensiontype'], row_hash['origin'], row_hash['productiondate'], row_hash['season'], row_hash['remain'],row_hash['suppliercomment'], row_hash['rp'], row_hash['actualdate']], :style => default 
			end
		end 

	  end
	end
	xls_file.serialize temp.path
    send_file temp.path, :filename => "vsikolesa.xls", :type => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
end

get '/orders' do
	if admin?
		protected!

		if params[:item] == nil
			@order_item = ""
			if params[:order_hash] == nil
				@order_hash = {}
			else	
				@order_hash = JSON.parse(params[:order_hash])
			end	
		else
			@order_item = params[:item].gsub(/row/,'')
			order_array = $db.execute("SELECT dimensiontype, brand, family, supplier, sp, spc, bp FROM price where id = ?",@order_item).flatten
			@order_hash = {'article' => (order_array[0] + " " + order_array[1] + " " + order_array[2]), 'supplier' => order_array[3], 'sp' => order_array[4], 'spc' => order_array[5], 'bp' => order_array[6]}
			@order_hash.each_pair do |order_key, order_value|
				if order_value.class == Float	
	  				@order_hash[order_key] = order_value.round(2)
		  		end	
		  		if (order_key == 'sp') and (@order_hash['sp'] != 0 or @order_hash['sp'] != "невідомо")
		  			if @order_hash['spc'] == "1"
		  				@order_hash[order_key] = @order_hash[order_key].ceil.to_s + " грн."
		  			elsif  @order_hash['spc'] == "2"
		 				@order_hash[order_key] = (@order_hash[order_key] + 0.0499999).round(1).to_s + " $"
		  			elsif  @order_hash['spc'] == "3"
		  				@order_hash[order_key] = (@order_hash[order_key] + 0.0499999).round(1).to_s + " &euro;"
		  			elsif  @order_hash['spc'] == "4"
		  				@order_hash[order_key] = (@order_hash[order_key] + 0.0499999).round(1).to_s + " PLN"
		  			end
		  		end
		  		if (order_key == 'sp') and (@order_hash['sp'] == 0 or @order_hash['sp'] == "невідомо")
		  			@order_hash[order_key] = "невідомо"	
		  		end
		  		if (order_key == 'supplier')
		  			@order_hash[order_key] = @order_hash[order_key].gsub(/№/,"")
		  		end
			end
		end		
		
		select_data_from_orders_db()
		@buyers_telephones = $db_orders.execute("SELECT name,telephone FROM buyers")
		@error_date_rows = $db_orders.execute("SELECT id FROM orders WHERE expected_receive_date <= sent").flatten
		if params[:show_modal] == nil
			@show_modal = ""
		else
			@show_modal = params[:show_modal]
		end	
		if params[:edit_item] == nil
			@edit_item = ""
		else
			@edit_item = params[:edit_item].gsub!(/row/,'')
		end	
		if params[:view_all_orders] == nil
			@view_all_orders = [{'name' => 'view_all_orders', 'value' => "false"}]
			expected_receive_date_array = $db_orders.execute("SELECT expected_receive_date FROM orders WHERE (receive_date ISNULL or receive_date IS '')").flatten	
		else
			@view_all_orders = [{'name' => 'view_all_orders', 'value' => params[:view_all_orders]}]
			expected_receive_date_array = $db_orders.execute("SELECT expected_receive_date FROM orders").flatten.uniq
		end
		@expected_receive_date_array = []
		expected_receive_date_array.each do |date_value|
			if date_value.scan(/(\d{4})\D(\d{2})\D(\d{2})/).flatten.empty? == false 
			  	date = date_value.scan(/(\d{4})\D(\d{2})\D(\d{2})/).flatten
			  	@expected_receive_date_array.push(Time.new(date[0].to_i,date[1].to_i,date[2].to_i).strftime("%m/%d/%Y"))
			end	
		end
		erb :orders
	end	
end 

post '/orders_table' do
	if admin?
		protected!
		sortname_column = params[:sortname]
		rp_number = params[:rp]
		page_number = params[:page]
		sortorder_value = params[:sortorder]
		if params[:view_all_orders] == nil
			view_all_orders = "false"
		else
			view_all_orders = params[:view_all_orders]
		end

		offset_value = page_number.to_i * rp_number.to_i - rp_number.to_i
		if view_all_orders == "true"
			select_string = "SELECT * FROM orders"	
		else
			select_string = "SELECT * FROM orders where (receive_date ISNULL or receive_date IS '')"
		end	
		select_count = select_string.gsub(/\*/,"count(*)")
		orders_count = $db_orders.execute(select_count).flatten
		select_all_orders = $db_orders.execute(select_string + " order by " + sortname_column + " " + sortorder_value + " limit " + rp_number + " offset " + offset_value.to_s)
		 
		all_orders_array = []
		select_all_orders.each do |one_row_data|
			data_hash = {}
			one_row_data.each_index do |index|
				data_hash[Orders_table_columns[index]] = one_row_data[index]
			end
			all_orders_array.push(data_hash)
		end
		
		all_orders_array.each_index do |all_orders_array_index|
			orders_hash = all_orders_array.at(all_orders_array_index)
			orders_hash.each_pair do |orders_hash_key, orders_hash_value|	
		  		if orders_hash_key == 'payed_by_buyer' or orders_hash_key == 'payed_by_us' or orders_hash_key == 'cash_flag'
		  			if orders_hash_value == 1
		  				all_orders_array[all_orders_array_index][orders_hash_key] = "Так"
		  			else
		  				all_orders_array[all_orders_array_index][orders_hash_key] = "Ні"	
		  			end	
		  		end
		  		if orders_hash_key == 'status'
		  			all_orders_array[all_orders_array_index][orders_hash_key] = Status_values_array[orders_hash_value.to_i]
		  		end
		  		if (orders_hash_key == 'issued' or orders_hash_key == 'reserve_date' or orders_hash_key == 'sent' or orders_hash_key == 'expected_receive_date' or orders_hash_key == 'receive_date') and orders_hash_value != "" and orders_hash_value != nil
					if orders_hash_value.scan(/(\d{2})\D(\d{2})\D(\d{4})/).flatten.empty? == false
		  				date = orders_hash_value.scan(/(\d{2})\D(\d{2})\D(\d{4})/).flatten
		  				all_orders_array[all_orders_array_index][orders_hash_key] = Time.new(date[2].to_i,date[1].to_i,date[0].to_i).strftime("%d/%m")
		  			end
		  			if orders_hash_value.scan(/(\d{4})\D(\d{2})\D(\d{2})/).flatten.empty? == false
		  				date = orders_hash_value.scan(/(\d{4})\D(\d{2})\D(\d{2})/).flatten
		  				all_orders_array[all_orders_array_index][orders_hash_key] = Time.new(date[0].to_i,date[1].to_i,date[2].to_i).strftime("%d/%m")
		  			end	
		  			
		  		end	
			end
		end

		select_data = {}
		rows_array = []

		all_orders_array.each do |value_hash|
			rows_array.push({"id" => value_hash["id"], "cell" => value_hash})
		end
		select_data["page"] = page_number
		select_data["total"] = orders_count
		select_data["rows"] = rows_array
		select_data["post"] = []
		return (JSON.pretty_generate(select_data))
	end	
end

get '/delete_orders' do
	if admin?
		protected!
		delete_array= []
		params[:items].each do |item|
			delete_array.push(item.gsub!(/row/,''))
		end
		@bind_hash = {}
		delete_select_string = 'DELETE FROM orders WHERE'
		delete_array.each_index do |array_index|
			if (array_index == 0)
				delete_select_string += " id=:id" + array_index.to_s
				@bind_hash[("id" + array_index.to_s).to_sym] = delete_array[array_index].to_i
			else
				delete_select_string += " or id=:id" + array_index.to_s
				@bind_hash[("id" + array_index.to_s).to_sym] = delete_array[array_index].to_i
			end
		end
		$db_orders.execute(delete_select_string, @bind_hash)
		redirect('/orders')
	end
end

get '/edit_modal_form' do
	if admin?
		protected!
		@edit_item = params[:item].gsub!(/row/,'')

		select_edit_row = $db_orders.execute("SELECT * FROM orders WHERE id=?", [@edit_item]).flatten
		@edit_data_hash = {}
		select_edit_row.each_index do |index|
			@edit_data_hash[Orders_table_columns[index]] = select_edit_row[index]
		end
		@edit_data_hash.each_pair do |key,value|
			if (key == 'reserve_date' or key == 'sent' or key == 'expected_receive_date' or key == 'receive_date') and value != "" and value != nil
				if value.scan(/(\d{2})\D(\d{2})\D(\d{4})/).flatten.empty? == false
		  			date = value.scan(/(\d{2})\D(\d{2})\D(\d{4})/).flatten
		  			@edit_data_hash[key] = Time.new(date[2].to_i,date[1].to_i,date[0].to_i).strftime("%d/%m/%Y")
		  		end
		  		if value.scan(/(\d{4})\D(\d{2})\D(\d{2})/).flatten.empty? == false
		  			date = value.scan(/(\d{4})\D(\d{2})\D(\d{2})/).flatten
		  			@edit_data_hash[key] = Time.new(date[0].to_i,date[1].to_i,date[2].to_i).strftime("%d/%m/%Y")
		  		end	
		  			
		  	end	
		end
		@buyers_telephones = $db_orders.execute("SELECT name,telephone FROM buyers")
		erb :edit_modal_form, :layout => false
	end	
end

def boolean_hash_check(hash,check)
	if hash.has_key?(check)
		return 1
	else
		return 0	
	end
end		

post '/edit_order' do
	if admin?
		protected!
		input_params_hash = {}
		params.each_pair do |input_param_key, input_param_value|
			param_key = input_param_key.gsub(/edit_/,"").to_sym
			if (param_key == :status)|| (param_key == :id)
				input_params_hash[param_key] = input_param_value.to_i
			else
				input_params_hash[param_key] = input_param_value
			end	
			input_params_hash[param_key] = "" if input_param_value == nil
		end

		input_params_hash.each_pair do |key, value|
			if (key == :payed_by_buyer) or (key == :payed_by_us) or (key == :cash_flag)
				input_params_hash[key] = boolean_hash_check(params,"edit_" + key.to_s)
			end
			if (key == :reserve_date or key == :sent or key == :expected_receive_date or key == :receive_date) and value != "" and value != nil
				if value.scan(/(\d{2})\D(\d{2})\D(\d{4})/).flatten.empty? == false
		  			date = value.scan(/(\d{2})\D(\d{2})\D(\d{4})/).flatten
		  			input_params_hash[key] = Time.new(date[2].to_i,date[1].to_i,date[0].to_i).strftime("%Y-%m-%d")
		  		end
		  		if value.scan(/(\d{4})\D(\d{2})\D(\d{2})/).flatten.empty? == false
		  			date = value.scan(/(\d{4})\D(\d{2})\D(\d{2})/).flatten
		  			input_params_hash[key] = Time.new(date[0].to_i,date[1].to_i,date[2].to_i).strftime("%Y-%m-%d")
		  		end	
		  			
		  	end	
		end
		input_params_hash[:issued] = Time.now.strftime("%Y-%m-%d")

		$db_orders.execute("UPDATE orders SET issued=:issued, buyer=:buyer, article=:article, amount=:amount, supplier=:supplier, inprice=:inprice, rate=:rate, outprice=:outprice, transfered=:transfered, transferprice=:transferprice, payed_by_buyer=:payed_by_buyer, payed_by_us=:payed_by_us, status=:status, bank=:bank, sent=:sent, track_id=:track_id, cash_flag=:cash_flag, notes=:order_notes, reserve_date=:reserve_date, expected_receive_date=:expected_receive_date, receive_date=:receive_date, post_name=:post_name, specification=:specification WHERE id=:id", input_params_hash)
		redirect('/orders')
	end
end

post '/add_new_order' do
	if admin?
		protected!
		input_params_hash = {}
		params.each_pair do |input_param_key, input_param_value|
			input_params_hash[input_param_key] = input_param_value
			input_params_hash[input_param_key] = 1 if input_param_value == "on"
			input_params_hash[input_param_key] = "" if input_param_value == nil
		end
		$db_orders.execute("INSERT INTO orders(issued, buyer, article, amount, supplier, inprice, outprice, status, reserve_date, expected_receive_date, notes) VALUES (?,?,?,?,?,?,?,?,?,?,?)", [Time.now.strftime("%Y-%m-%d"),input_params_hash["typeahead_buyer"],input_params_hash["input_article"], input_params_hash["input_amount"], input_params_hash["input_supplier"], input_params_hash["input_inprice"],  input_params_hash["input_outprice"], input_params_hash["input_status"], Time.now.strftime("%Y-%m-%d"), input_params_hash["expected_receive_date"], input_params_hash["input_order_notes"]])
		redirect('/orders')
	end
end

post '/add_new_buyer' do
	if admin?
		protected!

		input_params_hash = {}
		params.each_pair do |input_param_key, input_param_value|
			input_params_hash[input_param_key] = input_param_value
			input_params_hash[input_param_key] = "" if input_param_value == nil
		end
		$db_orders.execute("INSERT INTO buyers(name, fullname, telephone, city, contact_person, notes) VALUES (?,?,?,?,?,?)", [input_params_hash["input_buyer"],input_params_hash["input_fullname"],input_params_hash["input_telephone"],input_params_hash["input_city"],input_params_hash["input_contact_person"],input_params_hash["input_buyer_notes"]])
		if input_params_hash['shown_modal'] == nil or input_params_hash['shown_modal'] == ""
			redirect('/buyers')
		else
			return input_params_hash["input_buyer"]
			#redirect(URI.escape('/orders?buyer_redirect=true'))
		end	
	end
end

get '/buyers' do
	if admin?
		protected!
		select_data_from_orders_db()
		@buyers_telephones = $db_orders.execute("SELECT name, telephone FROM buyers")
		buyers_from_orders_table = $db_orders.execute("SELECT distinct buyer FROM orders").flatten
		@buyers_from_orders_table = []
		buyers_from_orders_table.each do |buyer|
			@buyers_from_orders_table.push('row' + buyer)
		end
		erb :buyers
	end	
	
end

post '/buyers_table' do
	if admin?
		protected!
		sortname_column = params[:sortname]
		rp_number = params[:rp]
		page_number = params[:page]
		sortorder_value = params[:sortorder]
		
		offset_value = page_number.to_i * rp_number.to_i - rp_number.to_i
		select_string = "SELECT * FROM buyers " + " order by " + sortname_column + " " + sortorder_value + " limit " + rp_number + " offset " + offset_value.to_s	
		all_buyers_array = []
		buyers_count = $db_orders.execute("SELECT count(*) FROM buyers")
		select_all_buyers = $db_orders.execute(select_string)
		
		select_all_buyers.each do |one_row_data|
			data_hash = {}
			one_row_data.each_index do |index|
				data_hash[Buyers_table_columns[index]] = one_row_data[index]
			end
			all_buyers_array.push(data_hash)
		end

		select_data = {}
		rows_array = []

		all_buyers_array.each do |value_hash|
			rows_array.push({"id" => value_hash["name"], "cell" => value_hash})
		end
		
		select_data["page"] = page_number
		select_data["total"] = buyers_count
		select_data["rows"] = rows_array
		select_data["post"] = []
		return (JSON.pretty_generate(select_data))
	end
end


get '/delete_buyers' do
	if admin?
		protected!
		delete_array= []
		params[:items].each do |item|
			delete_array.push(item.gsub!(/row/,''))
		end
		@bind_hash = {}
		delete_select_string = 'DELETE FROM buyers WHERE'
		delete_array.each_index do |array_index|
			if (array_index == 0)
				delete_select_string += " name=:name" + array_index.to_s
				@bind_hash[("name" + array_index.to_s).to_sym] = delete_array[array_index]
			else
				delete_select_string += " or name=:name" + array_index.to_s
				@bind_hash[("name" + array_index.to_s).to_sym] = delete_array[array_index]
			end
		end
		$db_orders.execute(delete_select_string, @bind_hash)
		redirect('/buyers')
	end	
end


get '/edit_buyer_modal_form' do
	if admin?
		protected!
		@edit_item = params[:item]
		@edit_item.gsub!(/row/,'')

		select_edit_row = $db_orders.execute("SELECT * FROM buyers WHERE name=?", [@edit_item]).flatten
		@edit_data_hash = {}
		select_edit_row.each_index do |index|
			@edit_data_hash[Buyers_table_columns[index]] = select_edit_row[index]
		end
		@buyers = $db_orders.execute("SELECT name FROM buyers").flatten
		erb :edit_buyer_modal_form, :layout => false
	end	
end

post '/edit_buyer' do
	if admin?
		protected!
		input_params_hash = {}
		params.each_pair do |input_param_key, input_param_value|
			param_key = input_param_key.gsub(/edit_/,"").to_sym
			input_params_hash[param_key] = input_param_value
			input_params_hash[param_key] = "" if input_param_value == nil
		end
		$db_orders.execute("UPDATE buyers SET name=:name, fullname=:fullname, telephone=:telephone, city=:city, contact_person=:contact_person, notes=:notes WHERE name=:item", input_params_hash)
		redirect('/buyers')
	end
end

post '/orders_excel' do
	if admin?
	protected!
		expected_receive_date_hash = {:first_date => params[:expected_receive_date_first], :second_date => params[:expected_receive_date_second]}
		expected_receive_date_hash.each_pair do |key,value|
			date = value.scan(/(\d{2})\D(\d{2})\D(\d{4})/).flatten
		  	expected_receive_date_hash[key] = Time.new(date[2].to_i,date[1].to_i,date[0].to_i).strftime("%Y-%m-%d")
		end
		if params[:view_all_orders] == nil or params[:view_all_orders] == "false"
			select_all_data = $db_orders.execute("SELECT orders.buyer, buyers.fullname, buyers.telephone, buyers.city, orders.article, orders.amount, orders.supplier, orders.sent, orders.expected_receive_date, orders.post_name, orders.track_id FROM orders, buyers WHERE (orders.buyer=buyers.name AND (orders.expected_receive_date BETWEEN :first_date AND :second_date) AND (receive_date ISNULL or receive_date IS ''))", expected_receive_date_hash)
		else
			select_all_data = $db_orders.execute("SELECT orders.buyer, buyers.fullname, buyers.telephone, buyers.city, orders.article, orders.amount, orders.supplier, orders.sent, orders.expected_receive_date, orders.post_name, orders.track_id FROM orders, buyers WHERE (orders.buyer=buyers.name AND (orders.expected_receive_date BETWEEN :first_date AND :second_date))", expected_receive_date_hash)
		end
		
		all_data_array = []
		select_all_data.each do |one_row_data|
			data_hash = {}
			one_row_data.each_index do |index|
				data_hash[Orders_table_excel_columns[index]] = one_row_data[index]
			end
			all_data_array.push(data_hash)
		end
		
		temp = Tempfile.new("orders.xls")
		xls_file = Axlsx::Package.new
		xls_file.workbook do |wb|
		  # define your regular styles
		  styles = wb.styles
		  header = styles.add_style(:bg_color => '00CCFF', :b => true, :border => { :style => :thin, :color => "00" }, :alignment => { :horizontal => :center, :vertical => :center , :wrap_text => true})
		  default = styles.add_style(:border => { :style => :thin, :color => "00" }, :alignment => { :horizontal => :left, :vertical => :center , :wrap_text => true})

		  wb.add_worksheet(:name => 'orders') do  |ws|
			ws.add_row [Orders_table_headers['buyer'], Buyers_table_headers['fullname'], Buyers_table_headers['telephone'], Buyers_table_headers['city'], Orders_table_headers['article'], Orders_table_headers['amount'], Orders_table_headers['supplier'], Orders_table_headers['sent'], Orders_table_headers['expected_receive_date'],Orders_table_headers['post_name'],Orders_table_headers['track_id']],  :style => header
			all_data_array.each do |row_hash|
				ws.add_row [row_hash['buyer'], row_hash['fullname'], row_hash['telephone'], row_hash['city'], row_hash['article'], row_hash['amount'], row_hash['supplier'], row_hash['sent'], row_hash['expected_receive_date'],row_hash['post_name'],row_hash['track_id']], :style => default 
			end	
		  end
		end
		xls_file.serialize temp.path
		send_file temp.path, :filename => "orders.xls", :type => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end 
end

__END__

@@ models

	<%@families.sort.each do |family|%>
		<div class="row-fluid">
			<div class="span2">
				<label class="checkbox">   
					<input name="tyre_family[]" type="checkbox" value="<%=family%>"><%=family%>
				</label>
			</div>
		</div>
	<%end%>




