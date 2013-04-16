# -*- encoding : utf-8 -*-
require 'rubygems'
require 'sinatra'
require 'sqlite3'
require 'json'
require 'cgi'
require 'net/http'
require 'uri'
set :protection, :except => :ip_spoofing


if File.exists?("tyre.db")
    db = SQLite3::Database.new("tyre.db")
end

Title = "Каталог шин"

Tyre_providers = db.execute("select distinct supplier from price")
Tyre_size = db.execute("select distinct sectionsize from price order by sectionsize asc").flatten

Tyre_diameter = db.execute("select distinct diameterc from price order by diameterc asc").flatten
Tyre_season = db.execute("select distinct season from price order by diameterc asc").flatten
Seasons = ["-", "літо", "зима", "в/c"]
Remain = Array.new(10000){ |index| index.to_s}

tyre_family_brand_name = db.execute("select distinct family, brand from price")


tyre_family_brand = {}


tyre_family_brand_name.each do |brand_family|
	if !tyre_family_brand.has_key?(brand_family.last)
		tyre_family_brand[brand_family.last] = []
	end
        tyre_family_brand[brand_family.last].push(brand_family.first)
end
tyre_family = tyre_family_brand.values.flatten.uniq.sort
Tyre_brand_name = tyre_family_brand.keys.sort
Tyre_family_brand_name = tyre_family_brand
Tyre_family_name = tyre_family

Data_field = ['id', 'brand', 'family', 'origin', 'comment', 'remain', 'moreflag', 'supplier', 'sp', 'spc', 'sourcestring', 'minimalorder', 'deliverytyme', 'suppliercomment', 'actualdate', 'runflat', 'sidewall', 'productiondate', 'diameterc', 'application', 'season', 'traileraxle', 'steeringaxle', 'driveaxle', 'dimensiontype', 'sectionsize', 'bp', 'bpvat', 'bppe', 'rp', 'rpvat', 'rppe']
Show_data_field = ['id','brand', 'family', 'dimensiontype', 'sidewall', 'origin', 'runflat', 'productiondate', 'season', 'bp', 'remain', 'supplier', 'rp', 'sp', 'suppliercomment', 'bpvat', 'actualdate', 'sourcestring']
Header_data_field = {'id' => 'Вибрати', 'family' => 'Модель', 'season' => 'Сезон', 'dimensiontype' => 'Типорозмір', 'bp' => 'Гуртова ціна', 'rp' => 'Роздрібна ціна'}

    Tyre_family_brand_name.each_pair do |brand,families|
    	Tyre_family_brand_name[brand] = []
		families.each do |one_family|
			Tyre_family_brand_name[brand].push(one_family)
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


get '/' do
    @message = "Для пошуку даних обов'язково введіть параметр Ширина/Висота"
    @message_no_data = "Немає даних, що відповідають вибраним значенням"
    if params[:press_reset_button] == "true"
    	@select_brands = []
		@select_families = []
		@select_sizes = []
		@select_diameters = []
		@select_seasons = []
		@select_date = ""
		@select_remain = ""
    else	
		@select_brands = select_values(params[:tyre_brand_selected],params[:tyre_brand_typeahead],Tyre_brand_name)
		@select_families = select_values(params[:tyre_family_selected],params[:tyre_family_typeahead],Tyre_family_name)
		@select_sizes = select_values(params[:tyre_size_selected],params[:tyre_size_typeahead],Tyre_size)
		@select_diameters = select_values(params[:tyre_diameter_selected],params[:tyre_diameter_typeahead],Tyre_diameter)
		@select_seasons = select_values(params[:tyre_season_selected],Seasons.index(params[:tyre_season_typeahead]).to_s,Tyre_season)

		if params[:tyre_date_selected] == nil
			@select_date = ""
		else
			if params[:tyre_date_selected] != ""
				@select_date = params[:tyre_date_selected]
			else
				@select_date = ""
			end	
		end
		if params[:input_date] == nil
			@select_date = ""
		else	
			if params[:input_date] != ""
				@select_date = params[:input_date]
			end
		end	
	
		if params[:tyre_remain_selected] == nil
			@select_remain = ""
		else
			if params[:tyre_remain_selected] != ""
				@select_remain = params[:tyre_remain_selected]
			else
				@select_remain = ""
			end	
		end
		if params[:tyre_remain_typeahead] == nil
			@select_remain = ""
		else	
			if params[:tyre_remain_typeahead] != ""
				@select_remain = params[:tyre_remain_typeahead]
			end
		end	
	
	end

	tyre_family_help_array = [] 
    if @select_brands.empty?
		tyre_family_help_array = Tyre_family_name
	else	
		help_array = []
		Tyre_family_brand_name.each_pair do |brand,brand_families|
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
	#make_href(@select_brands,"&brand","&brand[]")
	make_href(@select_families,"&family","&family[]")
	make_href(@select_sizes,"&size","&size[]")
	make_href(@select_diameters,"&diameter","&diameter[]")
	make_href(@select_seasons,"&season","&season[]")
	@table_url= @table_href
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
					select_string = filter_select(select_string, tyre_sizes_check, Tyre_size, "sectionsize = :size" + i.to_s, "size" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_sizes_check, Tyre_size, " or sectionsize = :size" + i.to_s, "size" + i.to_s)
				end
				i += 1
			end
			select_string =  select_string + " ) "
	
			if @select_brands.empty? == false
				select_string = select_string + " and ( "
				i=0
				@select_brands.each do |tyre_brands_check|
					if i == 0
						select_string = filter_select(select_string, tyre_brands_check, Tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_brands_check, Tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
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
						select_string = filter_select(select_string, tyre_families_check, Tyre_family_name, "family = :family" + i.to_s, "family" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_families_check, Tyre_family_name, " or family = :family" + i.to_s, "family" + i.to_s)
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
						select_string = filter_select(select_string, tyre_diameters_check, Tyre_diameter, "diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_diameters_check, Tyre_diameter, " or diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
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
						select_string = filter_select(select_string, tyre_seasons_check, Tyre_season, "season = :season" + i.to_s, "season" + i.to_s)
					else
						select_string = filter_select(select_string, tyre_seasons_check, Tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
					end
					i += 1
				end
				select_string =  select_string + " ) "
			end
	
			if @select_remain.empty? == false
				select_string = select_string + " and (remain >= :remain or remain = 0) "
				@bind_hash["remain".to_sym] = @select_remain
			end
	
			if @select_date.empty? == false
				select_string = select_string + " and (actualdate >= :date) "
				date = @select_date.scan(/(\d+)\/(\d+)\/(\d+)/).flatten
				@bind_hash["date".to_sym] = Time.gm(date[2],date[1],date[0]).strftime("%Y-%m-%d %H:%M:%S")
			end
	
			select_string = select_string + "group by brand order by brand"

			select_brand_price_array = db.execute(select_string, @bind_hash)
	
			@select_brand_price_hash = {}
			select_brand_price_array.each do |brand_price_array|
				@select_brand_price_hash[brand_price_array.first] = [brand_price_array[1],brand_price_array[2],brand_price_array[3],brand_price_array[4]]
			end
			if @select_brand_price_hash.empty?
				@show_table = false
			end
			
		else
			@message = "Для відображення даних натисніть ПОШУК"
		end	
	else 
		@message = "Для пошуку даних обов'язково введіть параметр Ширина/Висота"	
	end

    erb :filter

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
    select_seasons = params[:season]
    select_seasons = "" if select_seasons == nil 
    select_date = params[:date]
    select_date = "" if select_date == nil 
    select_remain = params[:remain]
    select_remain = "" if select_remain == nil 
    
    
    select_string = "select * from price where"
	select_string = select_string + " ( "
	i=0
	select_sizes.each do |tyre_sizes_check|
		if i == 0
			select_string = filter_select(select_string, tyre_sizes_check, Tyre_size, "sectionsize = :size" + i.to_s, "size" + i.to_s)
		else
			select_string = filter_select(select_string, tyre_sizes_check, Tyre_size, " or sectionsize = :size" + i.to_s, "size" + i.to_s)
		end
		i += 1
	end
	select_string =  select_string + " ) "
	
	if select_brands.empty? == false
		select_string = select_string + " and ( "
		i=0
		select_brands.each do |tyre_brands_check|
			if i == 0
				select_string = filter_select(select_string, tyre_brands_check, Tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_brands_check, Tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
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
				select_string = filter_select(select_string, tyre_families_check, Tyre_family_name, "family = :family" + i.to_s, "family" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_families_check, Tyre_family_name, " or family = :family" + i.to_s, "family" + i.to_s)
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
				select_string = filter_select(select_string, tyre_diameters_check, Tyre_diameter, "diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_diameters_check, Tyre_diameter, " or diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
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
				select_string = filter_select(select_string, tyre_seasons_check, Tyre_season, "season = :season" + i.to_s, "season" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_seasons_check, Tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
			end
			i += 1
		end
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
	
	all_data_array = []
	show_data_array = []
	select_all_data = db.execute(select_string, @bind_hash)
	select_all_data.each do |one_row_data|
		data_hash = {}
		show_data_hash = {}
		one_row_data.each_index do |index|
			data_hash[Data_field[index]] = one_row_data[index]
			if Header_data_field.has_key?(Data_field[index])
				show_data_hash[Data_field[index]] = one_row_data[index]
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
    select_seasons = params[:season]
    select_seasons = [] if select_seasons == nil 
    select_date = params[:date]
    select_date = "" if select_date == nil 
    select_remain = params[:remain]
    select_remain = "" if select_remain == nil 
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
	@message = "Ви не вибрали жодного елементу"
	erb :selected_items
end

post '/table_selected_items' do
	p "--------------------------------"
 	select_brands = params[:brand]
	select_brands = [] if select_brands == nil 	
    select_families = params[:family]
    select_families = [] if select_families == nil 
    select_sizes = params[:size]
    select_diameters = params[:diameter]
    select_diameters = [] if select_diameters == nil 
    select_seasons = params[:season]
    select_seasons = [] if select_seasons == nil 
    select_date = params[:date]
    select_date = "" if select_date == nil 
    select_remain = params[:remain]
    select_remain = "" if select_remain == nil 
	@checked_id_array = params[:checked_id]
	@checked_id_array = [] if @checked_id_array == nil 	
	@checked_brand_array = params[:checked_brand]
	@checked_brand_array = [] if @checked_brand_array == nil 	
	@bind_hash = {}
    sortname_column = params[:sortname]
    sortorder_value = params[:sortorder]
    sortname_column = params[:sortname]
    rp_number = params[:rp]
    page_number = params[:page]
    sortorder_value = params[:sortorder]
    
    select_string = "select * from price where"

    if @checked_brand_array.empty? == false
    	select_string = select_string + " ( "
		i=0
		select_sizes.each do |tyre_sizes_check|
			if i == 0
				select_string = filter_select(select_string, tyre_sizes_check, Tyre_size, "sectionsize = :size" + i.to_s, "size" + i.to_s)
			else
				select_string = filter_select(select_string, tyre_sizes_check, Tyre_size, " or sectionsize = :size" + i.to_s, "size" + i.to_s)
			end
			i += 1
		end
		select_string =  select_string + " ) "
	
		if select_families.empty? == false
			select_string = select_string + " and ( "
			i=0
			select_families.each do |tyre_families_check|
				if i == 0
					select_string = filter_select(select_string, tyre_families_check, Tyre_family_name, "family = :family" + i.to_s, "family" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_families_check, Tyre_family_name, " or family = :family" + i.to_s, "family" + i.to_s)
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
					select_string = filter_select(select_string, tyre_diameters_check, Tyre_diameter, "diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_diameters_check, Tyre_diameter, " or diameterc = :diameterc" + i.to_s, "diameterc" + i.to_s)
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
					select_string = filter_select(select_string, tyre_seasons_check, Tyre_season, "season = :season" + i.to_s, "season" + i.to_s)
				else
					select_string = filter_select(select_string, tyre_seasons_check, Tyre_season, " or season = :season" + i.to_s, "season" + i.to_s)
				end
				i += 1
			end
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
    	
		select_string = select_string + " and ( "
		i = 0
		@checked_brand_array.each do |checked_brand|
			if i == 0
				select_string = filter_select(select_string, checked_brand, Tyre_brand_name, "brand = :brand" + i.to_s, "brand" + i.to_s)
			else
				select_string = filter_select(select_string, checked_brand, Tyre_brand_name, " or brand = :brand" + i.to_s, "brand" + i.to_s)
			end
			i += 1
		end
		select_string =  select_string + " ) "
	end
    	
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

	select_count = select_string.gsub(/\*/,"count(*)")
	
	rows_count = db.execute(select_count, @bind_hash).flatten


	offset_value = page_number.to_i * rp_number.to_i - rp_number.to_i.to_i
	p select_string = select_string + " order by " + sortname_column + " " + sortorder_value + " limit " + rp_number + " offset " + offset_value.to_s	
		
	all_data_array = []
	select_all_data = db.execute(select_string, @bind_hash)
	select_all_data.each do |one_row_data|
		data_hash = {}
		one_row_data.each_index do |index|
			data_hash[Data_field[index]] = one_row_data[index]
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
        tyre_brands = Tyre_brand_name
    elsif params[:tyre_brand].empty? 
    	tyre_brands = Tyre_brand_name
    else	
    	tyre_brands = params[:tyre_brand]
    end
    tyre_brands.each do |tyre_brand|
        @families[tyre_brand] = db.execute("select family,brand from price where brand=?", tyre_brand).flatten
    end	
    @bind_hash = {}
    
    select_family = "select family from price where "
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
	
    families_brands = db.execute(select_family, @bind_hash)
   
    
    erb :models
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
			




