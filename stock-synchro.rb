require "csv"
require "prestashop"
require 'active_support/inflector'
require "net/smtp"
require "mail"
require "erb"
require "resend"
require "dotenv"
require "chatgpt"


Dotenv.load
# require_relative "deleter"
Resend.api_key = "re_WJntg4j3_Bt7i1GxsLXsdmsPSoZSvqPRF"

ChatGPT.configure do |config|
  config.api_key = ENV['OPENAI_API_KEY']
  config.api_version = 'v1'
  config.default_engine = 'gpt-4.1'  # For chat
  config.request_timeout = 30
  config.max_retries = 3
  config.default_parameters = {
    max_tokens: 16,
    temperature: 1.0,
    top_p: 1.0,
    n: 1
  }
end

# Database connection details
host = 'localhost'       # MySQL host
username = 'image-deleter'        # MySQL username
password = 'zXv4VK3m87QDpdsB4ypC'    # MySQL password
database = 'prestashop'  # The name of the database
references_to_keep = CSV.read('refs-a-garder-front-runner.csv')
references_to_keep_no_correspondance = references_to_keep.map { |r| r[0] }
# Mail settings
# Mail.defaults do
#   delivery_method :smtp, { 
#     address:              'ssl0.ovh.net',
#     port:                 587,
#     user_name:            "informatique@montpellier4x4.com",
#     password:             "Montpellier4x4Info",
#     authentication:       'plain',
#     enable_starttls_auto: true
#   }
# end

Mail.defaults do
  delivery_method :smtp, { 
    address:              'smtp.gmail.com',
    port:                 587,
    user_name:            "lesalfistes@gmail.com",
    password:             "waio wwoa qabf ogbw",
    authentication:       'plain',
    enable_starttls_auto: true
  }
end


# Create a MySQL2 client
# CLIENT = Mysql2::Client.new(
#   host: host,
#   username: username,
#   password: password,
#   database: database
# )

def delete_image_by_id(item_id)
  # SQL query to delete the item
  query = "DELETE FROM ps_image WHERE id_image = ?"
  # Prepare and execute the query
  statement = ::CLIENT.prepare(query)
  puts "deleting image with id #{item_id}"
  statement.execute(item_id)
end


# Fichier CSV
# CSV_URL = "https://api.frontrunner.co.za/customer/Edi/EUR?account=DMON802&ApiKey=6bbb3bd79df745fda029b2ff16957c54&format=csv"
# CSV_URL = "https://api.frontrunner.co.za/customer/Pricelist/file/EUR?account=DMON802&ApiKey=6bbb3bd79df745fda029b2ff16957c54&format=csv&language=FR&nonStandardColumns=dimensions&nonStandardColumns=bom&nonStandardColumns=narrative&nonStandardColumns=images"
# `curl -L "#{CSV_URL}" -o 'catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv'` unless File.exist?("catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv")
# JSON_URL = "https://api.frontrunner.co.za/customer/Pricelist/file/EUR?account=DMON802&ApiKey=6bbb3bd79df745fda029b2ff16957c54&format=json&language=FR&nonStandardColumns=dimensions&nonStandardColumns=categories&nonStandardColumns=narrative&nonStandardColumns=images"
# `curl -L "#{JSON_URL}" -o 'catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json'` unless File.exist?("catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json")

def download_front_runner_catalogue(language)
  Object.const_set("CSV_URL_#{language}", "https://api.frontrunner.co.za/customer/Pricelist/file/EUR?account=DMON802&ApiKey=6bbb3bd79df745fda029b2ff16957c54&format=csv&language=#{language}&nonStandardColumns=dimensions&nonStandardColumns=bom&nonStandardColumns=narrative&nonStandardColumns=images")
  csv_url = Object.const_get("CSV_URL_#{language}")
  Object.const_set("JSON_URL_#{language}", "https://api.frontrunner.co.za/customer/Pricelist/file/EUR?account=DMON802&ApiKey=6bbb3bd79df745fda029b2ff16957c54&format=json&language=EN&nonStandardColumns=dimensions&nonStandardColumns=categories&nonStandardColumns=narrative&nonStandardColumns=images")
  json_url = Object.const_get("JSON_URL_#{language}")
  Object.const_set("JSON_STOCK_URL_#{language}", "https://api.frontrunner.co.za/customer/Edi/EUR?account=DMON802&ApiKey=6bbb3bd79df745fda029b2ff16957c54&format=csv")
  json_stock_url = Object.const_get("JSON_STOCK_URL_#{language}")
  `curl -L "#{csv_url}" -o 'catalogue-front-runner-#{language}-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv'` unless File.exist?("catalogue-front-runner-#{language}-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv")
  `curl -L "#{json_url}" -o 'catalogue-front-runner-#{language}-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json'` unless File.exist?("catalogue-front-runner-#{language}-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json")
  `curl -L "#{json_stock_url}" -o 'stock-front-runner-#{language}-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv'` unless File.exist?("stock-front-runner-#{language}-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv")
end

download_front_runner_catalogue("FR")
download_front_runner_catalogue("EN")
Prestashop::Client::Implementation.create 'IKWHFE1ZKMJAQAGRBZ2NKIJQRIIEQMKL', 'https://www.montpellier4x4.com'

# Download latest CSV
begin
  available_references_csv = CSV.read("catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv").map { |(ref, desc, date_mod, currency, retail_price, discount_percent, discount_price, tariff, country, upc, brand)| [ref, brand] }
  available_references_json = JSON.parse(File.open("catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json").read) rescue JSON.dump("{}")
  available_references_csv_en = CSV.read("catalogue-front-runner-EN-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv").map { |(ref, desc, date_mod, currency, retail_price, discount_percent, discount_price, tariff, country, upc, brand)| [ref, brand] }
  available_references_json_en = JSON.parse(File.open("catalogue-front-runner-EN-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv").read) rescue JSON.load(JSON.dump([{}]))
rescue CSV::MalformedCSVError => e
  Resend::Emails.send({
    "from": "tom@presta-smart.com",
    "to": "tom@tombrom.dev",
    "subject": "Erreur en lisant les CSVs Front-Runner",
    "html":  e.message
  })
  raise e
end
dometic = available_references_csv.partition { |product| product[1] == "Dometic" }
their_dometic = dometic[0].map  {|p| p[0]}
puts "There are #{their_dometic.length} Dometic products in the current Front Runner catalogue"
our_dometic = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 95}, display: '[reference]').map { |h| h[:reference] } 
puts "We have #{our_dometic.length} Dometic products on our site" 
cadac = available_references_csv.partition { |product| product[1] == "CADAC" }
new_dometic = their_dometic - our_dometic
other = available_references_csv.partition { |product| product[1] == "Other" } 
new_other = other[0].map  {|p| p[0]}
our_petromax = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 116}, display: '[reference]').map { |h| h[:reference] }
petromax = available_references_csv.partition { |product| product[1] == "Petromax" }
their_petromax = petromax[0].map  {|p| p[0]}
old_dometic = our_dometic - their_dometic
old_dometic.reject! { |product| references_to_keep_no_correspondance.include?(product) }
old_dometic_info = []
old_dometic.each do |ref|
  product = Prestashop::Client.read :products, nil, {filter: {reference: ref}}
  product_id = product.dig(:products, :product, :attr, :id) rescue ""
  product_info = Prestashop::Mapper::Product.find(product_id) rescue ""
  name = product_info.dig(:name, :language)[0][:val] rescue ""
  info = "#{ref}: #{name}"
  old_dometic_info << info
end

def find_no_weights
  no_weights = []
  our_products = Prestashop::Mapper::Product.all(filter: { active: 1})
  our_products.each do |p|
    product_info = Prestashop::Mapper::Product.find(p)
    no_weight = product_info[:weight].to_f == 0
    if no_weight 
      name = product_info.dig(:name, :language)[0][:val] rescue ""
      no_weights << "ID: #{product_info[:id]}, Ref: #{product_info[:reference]}, Nom: #{name}"
    end
  end
  if no_weights.length > 0
    text = ERB.new(<<-BLOCK).result(binding)
    <ul>#{no_weights.join("<li>")}}</ul>
  BLOCK
    mail = Mail.new do
      from    'lesalfistes@gmail.com'
      to      'contact@montpellier4x4.com'
      cc 'lesalfistes@gmail.com'
      subject "#{no_weights.length} produits actifs sans poids ont été trouvés"
    
      text_part do
        body text
      end
    
      html_part do
        content_type 'text/html; charset=UTF-8'
        body text
      end
    end
    mail.deliver!
  end
end

# FRONT RUNNER
front_runner = available_references_csv.partition { |product| product[1] == "Front Runner" }
their_fr = front_runner[0].map {|p| p[0]}
puts "There are #{their_fr.length} Front Runner products in the current Front Runner catalogue"
our_fr = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 3}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "We have #{our_fr.length} Front Runner products on our site" 
our_cadac = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 136}, display: '[reference]').map { |h| h[:reference] } rescue []
cadac = available_references_csv.partition { |product| product[1] == "CADAC" }
their_cadac = cadac[0].map  {|p| p[0]}
old_cadac = our_cadac - their_cadac
new_cadac = their_cadac - our_cadac
new_fr = their_fr - our_fr
old_fr = our_fr - their_fr
old_fr.reject! { |product| references_to_keep_no_correspondance.include?(product) }
old_fr_info = []
old_fr.each do |ref|
  product = Prestashop::Client.read :products, nil, {filter: {reference: ref}}
  product_id = product.dig(:products, :product, :attr, :id) rescue ""
  product_info = Prestashop::Mapper::Product.find(product_id) rescue ""
  name = product_info.dig(:name, :language)[0][:val] rescue ""
  info = "#{ref}: #{name}"
  old_fr_info << info
end


# available_references_json.map { |code, desc, date, currency, price, discount, discount_percent, tariff, country, upc, brand, depth, length, width, depth_in, l| }
available_references_csv.shift
# old = CSV.read("baumgartner_full.csv").map do |(product_sku, b rand, brand_model, title, category, sub_category, material, color, description, quantity, price, shipping_cost, currency, shipping_deliverytime, condition, rpp, image_urls, gender, condition_description, location)|
#   product_sku
# end
# References of Front Runner products that we have on the site
# Front Runner
front_runner_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 3}, display: '[reference]').map { |h| h[:reference] }
puts "FRONT RUNNER HAS :#{front_runner_hash.length} products"
# front_runner_refs_only = our_catalogue_hash.map { |h| h[:reference] }
# Dometic
dometic_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 95}, display: '[reference]').map { |h| h[:reference] } 
puts "DOMETIC HAS :#{dometic_hash.length} products" 
#Aqua Signal
aquasignal_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 132}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "AQUA SIGNAL HAS :#{aquasignal_hash.length} products"
# CADAC 
cadac_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 136}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "CADAC HAS :#{cadac_hash.length} products"
# Deuro
deuro_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 140}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "DEURO HAS :#{deuro_hash.length} products"
# Grip n Co
grip_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 141}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "GRIP HAS #{grip_hash.length} products"
# James Baroud
baroud_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 20}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "JAMES BAROUD HAS #{baroud_hash.length} products"
# Lasher
lasher_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 138}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "LASHER HAS #{lasher_hash.length} products"
# Leisure Quip
leisure_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 135}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "LEISURE HAS #{leisure_hash.length} products"
# Max Trax
maxtrax_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 55}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "MAXTRAX HAS #{maxtrax_hash.length} products"
# Moto Quip
motoquip_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 133}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "MOTOQUIP HAS #{motoquip_hash.length} products"
# Osram
osram_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 137}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "OSRAM HAS #{osram_hash.length} products"
# Petromax
petromax_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 116}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "PETROMAX HAS #{petromax_hash.length} products"
# Rough & Tough
rough_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 156}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "ROGUH AND TOUGH HAS #{rough_hash.length} products"
# Surgeflow
surgeflow_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 157}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "SURGEFLOW HAS #{surgeflow_hash.length} products"
# Vickywood
vickywood_hash = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 154}, display: '[reference]').map { |h| h[:reference] } rescue []
puts "VICKYWOOD HAS #{maxtrax_hash.length} products"

all_front_runner = aquasignal_hash + front_runner_hash + cadac_hash + dometic_hash + deuro_hash + grip_hash + baroud_hash + lasher_hash + leisure_hash + maxtrax_hash + motoquip_hash + osram_hash + petromax_hash + rough_hash + surgeflow_hash + vickywood_hash

def optimize(text, desc_type)
  begin
    client = ChatGPT::Client.new(ENV['OPENAI_API_KEY'])
    char_limit = desc_type == "long" ? 21844 : 80000
    response = client.completions([{"role": "user", "content": "Please rephrase this text: #{text}. It cannot be longer than #{char_limit}. Please give me  just the result, I don't need text such as 'Here is a rephrased version within your limits'"}])
    response.dig("choices", 0, "message", "content")
  rescue => e
    puts "ChatGPT Failure: #{e.message}"
    Resend::Emails.send({
      "from": "toto@presta-smart.com",
      "to": "tom@tombrom.dev",
      "subject": "Erreur dans la méthode optimize impliquant chatGPT",
      "html":  e.message
    })
  end
end
# References to delete:
# FileUtils.touch("sold_products.json")
# File.open("sold_products.json", "w+") do |f|
#   f.puts JSON.dump(sold_products)
# end
# DELETE OLD PRODUCTS
def delete_products(products, product_info, brand)
  deleted_products = 0
  products.uniq.each do |product_ref|
    # Get product details
    puts "product ref is #{product_ref}"
    next if product_ref == "product_sku"
    product = Prestashop::Client.read :products, nil, {filter: {reference: product_ref}}
    if product[:products].is_a?(String)
      puts "Unable to find this product, must have been deleted already"
      next 
    end
    # Get ID
    id = product.dig(:products, :product)[0].dig(:attr, :id) rescue ""
    if id == ""
      id = product.dig(:products, :product, :attr, :id) rescue ""
    end
    full_product = Prestashop::Mapper::Product.find(id)
    puts "Successfully retrieved product id: #{id}"
    # Remove product or soft deletion, put it in "a supprimer" category
    begin
      current_categories = full_product.dig(:associations, :categories, :category)
      if current_categories.is_a?(Array)
        new_categories = current_categories << {id: 2961} 
      else
        # Make it an array
        new_categories = [current_categories, {id: 2961}]
      end
      Prestashop::Mapper::Product.update(id, associations: {categories: {attr: {nodetype: "category", api: "categories"}, category: new_categories}})
      # Prestashop::Client.delete :products, id
    rescue Prestashop::Api::RequestFailed => e
      mail = Mail.new do
        from    'lesalfistes@gmail.com'
        to      'tom@tombrom.dev'
        cc 'lesalfistes@gmail.com '
        subject "Erreur de suppression de l'article #{product_ref}"
      
        text_part do
          body "Erreur de suppression #{product_ref}"
        end
      
        html_part do
          content_type 'text/html; charset=UTF-8'
          body "<h2>L'article #{id} n'a pas pu être supprimé</h2><p>#{e.message}</p>"
        end
      end
      mail.deliver!
    end
    # FileUtils.touch("images.csv")
    # images.each do |img|
    #   image_array << img[:id]
    # end
    # CSV.open("images.csv", "a+") do |csv|
    #   csv << image_array
    # end
    # puts image_array
    puts "Successfully deleted product #{product_ref}"
    deleted_products += 1
    # Delete images
  end
  if deleted_products > 1
    text = ERB.new(<<-BLOCK).result(binding)
      <ul>#{product_info.join("<li>")}</ul>
    BLOCK
    Resend::Emails.send({
      "from": "toto@presta-smart.com",
      "to": "tom@tombrom.dev",
      "subject": "#{deleted_products} produits du catalogue #{brand} sont à supprimer.",
      "html":  "Vous pouvez les retrouver dans la catégorie 'A supprimer' à la racine" + text
    })
    # mail = Mail.new do
    #   from    'lesalfistes@gmail.com'
    #   to      'tom@montpellier4x4.com'
    #   cc 'lesalfistes@gmail.com'
    #   subject "#{deleted_products} produits du catalogue #{brand} sont à supprimer."
    
    #   text_part do
    #     body "Vous pouvez les retrouver dans la catégorie 'A supprimer' à la racine" + text
    #   end
    
    #   html_part do
    #     content_type 'text/html; charset=UTF-8'
    #     body text
    #   end
    # end
    # mail.deliver!
  end
end

# [[our_cadac, [], "Cadac"]].each do |products| 
#   delete_products(products[0], products[1], products[2]) 
# end

def translate_products(products, language)
  puts "STARTING TRANSLATION OF FRONT RUNNER PRODUCTS"
  begin
    available_references_json = JSON.parse(File.open("catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json").read)
    available_references_json_en = JSON.parse(File.open("catalogue-front-runner-EN-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json").read)
  rescue JSON::ParserError => e
    Resend::Emails.send({
      "from": "toto@presta-smart.com",
      "to": "tom@tombrom.dev",
      "subject": "Error parsing Front Runner catalogue",
      "html": "<p>#{e.message}</p>"
    })
    if e.message == "unexpected token at 'Too many requests'"
      # download_front_runner_catalogue(language, force: true)
      available_references_json = JSON.parse(File.open("catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json").read)
      available_references_json_en = JSON.parse(File.open("catalogue-front-runner-EN-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json").read)
    end
  end
  translated_products = 0
  products.each do |product|
    product_hash = available_references_json_en.find { |p| p["Code"] == product }
    product_hash_fr = available_references_json.find { |p| p["Code"] == product }
    # Get id
    product_id = Prestashop::Mapper::Product.find_by(filter: {reference: product})
    puts "PRODUCT ID: #{product_id}"
    if product_id
      # Get product info
      product_info = Prestashop::Mapper::Product.find(product_id)
      updated = false
      begin
        brand = product_hash["Brand"]
        fr_name = product_hash_fr["Description"]
        current_en_name = product_info[:name][:language][1][:val]
        new_name = product_hash["Description"]
        fr_short_desc = product_hash_fr["Narration"]
        current_en_short_desc =  product_info[:description_short][:language][1][:val]
        new_short_desc = product_hash["Narration"]
        fr_description = product_hash_fr["LongDescription"].gsub("\\n", "<br>") + "<br>" + product_hash_fr["Specification"].gsub("\\n", "<br>")
        current_en_description = product_info[:description][:language][1][:val]
        new_description = product_hash["LongDescription"].gsub("\\n", "<br>") + "<br>"  + product_hash["Specification"].gsub("\\n", "<br>")
        fr_meta_title = "Montpellier4x4 |" + " #{product_hash_fr["Brand"]} "+  product_hash_fr["Description"]
        en_meta_title = "Montpellier4x4 |" + " #{product_hash["Brand"]} "+  product_hash["Description"]
        fr_meta_description = product_hash_fr["Narration"][0...200]
        en_meta_description = product_hash["Narration"][0...200]
        translated = false
        if current_en_name == "" || current_en_name == fr_name
          puts "PRODUCT REF IS #{product}"
          puts "Current English Name is empty or same as French"
          unless current_en_name == new_name
            Prestashop::Mapper::Product.update(product_id, name: {language: [{attr: {id: 3}, val: new_name}, {attr: {id: 1}, val: fr_name}]}) 
            translated = true
          end
          translated_products += 1 unless translated
        end
        if current_en_short_desc == "" || current_en_short_desc == fr_short_desc
          puts "Current English Short Description is Empty or Same as French"
          Prestashop::Mapper::Product.update(product_id, description_short: {language: [{attr: {id: 3}, val: new_short_desc}, {attr: {id: 1}, val: fr_short_desc}]}) 
        end
        if current_en_description == "" || current_en_description == fr_description
          puts "Current English Description is empty or same as French"
          Prestashop::Mapper::Product.update(product_id, description: {language: [{attr: {id: 3}, val: new_description}, {attr: {id: 1}, val: fr_description}]}) 
        end
        Prestashop::Mapper::Product.update(product_id, meta_title: {language: [{attr: {id: 3}, val: en_meta_title}, {attr: {id: 1}, val: fr_meta_title}]}) 
        Prestashop::Mapper::Product.update(product_id, meta_description: {language: [{attr: {id: 3}, val: en_meta_description}, {attr: {id: 1}, val: fr_meta_description}]}) 
      rescue NoMethodError => e
        mail = Mail.new do
          from    'lesalfistes@gmail.com'
          to      't_bromehead@yahoo.fr'
          cc 't_bromehead@yahoo.fr'
          subject "MAJ Petromax: Erreur lors de la mise à jour de #{product["Name"]}"
        
          text_part do
            body "Détail de l'erreur #{e.message} pour le produit #{product_id} ref #{product}. "
          end
        
          html_part do
            content_type 'text/html; charset=UTF-8'
            body "<h2>Détail de l'erreur: #{e.message}  pour le produit #{product_id} ref #{product}.</h2>#{e.backtrace}<br />#{e.backtrace_locations}<br/>"
          end
        end
        mail.deliver!
      end
    end
  end
  if translated_products > 1
    mail = Mail.new do
      from    'informatique@montpellier4x4.com'
      to      'contact@montpellier4x4?.com'
      cc 't_bromehead@yahoo.fr'
      subject "MAJ Catalogue Front Runner: #{translated_products} produits ont été traduits en Anglais"
    end
    mail.deliver!
  end
end


# If needed get supplier ID
# Create Product
def create_front_runner_products(new_products, language=nil, rephrase=nil)
  created_products = 0
  return if new_products.length < 1
  new_product_info = []
  brand  = ""
  language = "FR" unless language
  # puts language
  # download_front_runner_catalogue(language)
  available_references_json = JSON.parse(File.open("catalogue-front-runner-#{language}-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json").read)
  new_products.each do |ref|
    build_args = Hash.new
    # Look up product in JSON Hash
    product_hash = available_references_json.find { |p| p["Code"] == ref }
    next unless product_hash
    # Check whether the product exits
    build_args["reference"] = product_hash["Code"]
    build_args["name"] = product_hash["Description"]
    build_args["price"] = product_hash["RetailPrice"].to_i
    build_args["ean13"] = product_hash["UPC"]
    build_args["brand"] = product_hash["Brand"]
    build_args["description_short"] = rephrase == true ? optimize(product_hash["Narration"], "short") : product_hash["Narration"]
    build_args["description"] = rephrase == true ? optimize(product_hash["LongDescription"].gsub("\\n", "<br>"), "long") : product_hash["LongDescription"].gsub("\\n", "<br>")
    build_args["description"] =  build_args["description"] + "<br>" + product_hash["Specification"]
    build_args["meta_title"] = "Montpellier4x4 vous propose le " + product_hash["Description"]
    build_args["weight"] = product_hash["Weight_kg"]
    build_args["meta_description"] = product_hash["Narration"][0...200]
    build_args["available_for_order"], build_args["available_now"] = 1, 1
    build_args["id_tax_rules_group"] = 9
    build_args["show_price"] = 1
    product = Prestashop::Mapper::Product.find_by(filter: {reference: build_args["reference"]})
    unless product
      # # Get id or English language
      # Set defaults for product
      id_lang = Prestashop::Mapper::Language.find_by_iso_code('fr')
      build_args["id_lang"] = id_lang
      id_manufacturer = Prestashop::Mapper::Manufacturer.find_by( filter: {name: build_args["brand"]}) rescue nil
      unless id_manufacturer
        # Send Warning Email that this manufacturer doesn't exist
        Resend::Emails.send({
          "from": "toto@presta-smart.com",
          "to": "tom@tombrom.dev",
          "subject": "Une nouvelle marque est apparue au catalogue Front-Runner",
          "html":  "La marque #{build_args["brand"]} est nouvelle et doit être créée"
        })
      end
      build_args.merge!({id_lang: id_lang, id_manufacturer: id_manufacturer})
      cat_name = "#{Date.today.day} #{Date::MONTHNAMES[Date.today.month]} #{Date.today.year} Import #{build_args["brand"]}"
      category_id = Prestashop::Mapper::Category.find_by(filter: { name: cat_name })
      unless category_id
        category = Prestashop::Mapper::Category.new({name: cat_name, id_lang: id_lang, link_rewrite: cat_name, active: 0})
        new_cat = category.create
        category_id = new_cat[:id]
      end
      build_args["available_for_order"], build_args["available_now"] = 1, 1
      build_args["id_category_default"] = category_id
      # Find weight attribute
      weight = Prestashop::Mapper::ProductFeature.find_in_cache("Poids", id_lang)
      weight_value = Prestashop::Mapper::ProductFeatureValue.find_in_cache(weight[:id], build_args["weight"], id_lang)
      unless weight_value
        temp_weight_value = Prestashop::Mapper::ProductFeatureValue.new(id_feature: weight[:id], value: build_args["weight"].to_s, id_lang: id_lang)
        weight_value = temp_weight_value.create
      end
      build_args["id_features"] = [
        ActiveSupport::HashWithIndifferentAccess.new({id_feature: weight[:id], id_feature_value: weight_value[:id]})
      ]
      draft_product = Prestashop::Mapper::Product.new(build_args)
      begin
        new_product = draft_product.create
      rescue Prestashop::Api::RequestFailed => e
        # Email error message
        puts e.message
      end
      if new_product[:id]
        puts "Product #{new_product[:name]} has been created"
        created_products += 1
        new_product_info << "Marque: #{build_args['brand']}, Ref: #{build_args['reference']}, Nom: #{build_args['name']}, Prix: #{build_args["price"]}€ HT"
        Prestashop::Mapper::Product.update(new_product[:id], state: 1, active: 1)
        # Upload images:
        (1..8).each do |n|
          image = Prestashop::Mapper::Image.new(resource: :products, id_resource: new_product[:id], source: product_hash["Image_#{n}"])
          if image
            puts "Uploading image for product #{new_product[:id]}"
            begin
              uploaded = image.upload
            rescue Prestashop::Api::RequestFailed
            end
          end
        end
        translate_products([new_product[:reference]], "EN")
      else
        puts "Skipping this product, already exists"
        # Product already exists
        next
      end
    end
  end
  if created_products >= 1
   text = ERB.new(<<-BLOCK).result(binding)
      <ul>#{new_product_info.join("<li>")}</ul>
    BLOCK
    mail = Mail.new do
      from    'lesalfistes@gmail.com'
      to      'contact@montpellier4x4.com'
      cc 'lesalfistes@gmail.com'
      subject "Création et traduction en anglais de #{created_products} produits du catalogue #{brand}"
    
      text_part do
        body "Produits crées, détail ci-dessous. Il faut maintenant les affecter aux bonnes catégories et \n sûrement revoir les noms car Front Runner ne fait pas beaucoup d'efforts pour traduire comme il faut ses produits..." + "\n" + text
      end
    
      html_part do
        content_type 'text/html; charset=UTF-8'
        body "Produits crées, détail ci-dessous. Il faut maintenant les affecter aux bonnes catégories et sûrement revoir les noms <br> car Front Runner ne fait pas beaucoup d'efforts pour traduire comme il faut ses produits..." + "\n"+ "<br><br>" + text
      end
    end
    # mail.deliver!
  end

end

# [new_fr].each { |products| create_front_runner_products(products)} 
# [new_cadac].each { |products| create_products(products)} 

def update_front_runner_products(products)
  binding.irb
  download_front_runner_catalogue("FR")
  available_references_json = JSON.parse(File.open("catalogue-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.json").read)
  stock = CSV.read("stock-front-runner-FR-#{Time.now.day}-#{Time.now.month}-#{Time.now.year}.csv")
  .map { |linecode, sku, mpn, upc, corecost, cost, l1, l2, l3, stock, eta, manufactured, leadtime| [sku, stock] }
  updated_products = 0
  brand = ""
  # We are looking for products via id_manufacturer = 3, some are already on the site but don't have that.
  # Which means we have to iterate by reference
  # Update products already on the site, then do the same with the ones 
  products.each do |product|
    product_hash = available_references_json.find { |p| p["Code"] == product }
    # Get id
    begin
      product_id = Prestashop::Mapper::Product.find_by(filter: {reference: product})
    rescue Prestashop::Api::ParserError
      product_id = Prestashop::Mapper::Product.find_by(filter: {reference: product[0]})
    end
    puts "PRODUCT REF IS: #{product}"
    if product_id
      # Get product info
      our_product_info = Prestashop::Mapper::Product.find(product_id)
      brand = our_product_info[:manufacturer_name][:val]
      puts "Empty brand for #{product}" if brand.empty?
      manufacturer = our_product_info[:id_manufacturer]
      updated = false
      begin 
        # Check price and update if different
        fr_price = product_hash["RetailPrice"].to_f 
        our_price = our_product_info[:price].to_f
        unless fr_price == our_price
          update = Prestashop::Mapper::Product.update(product_id, price: fr_price)
          updated = true
          updated_products += 1 if update.is_a?(Hash)
        end
        weight = our_product_info[:weight].to_f
        puts "PRODUCT WEIGHT IS: #{weight}"
        if weight.zero?
          #if update.is_a?(Hash)
          new_weight = product_hash["Weight_kg"].to_f
          puts "Weight was #{weight} and will now be #{new_weight}"
          update = Prestashop::Mapper::Product.update(product_id, weight: new_weight)
          if update.is_a?(Hash) && !updated
            updated_products += 1
          end
        end
        price_displayed = our_product_info[:show_price]
        if price_displayed.zero?
          Prestashop::Mapper::Product.update(product_id, show_price: 1) 
          puts "Price will now be displayed"
        end
        if our_product_info[:id_manufacturer].nil? 
          manufacturer_name = product_hash["Brand"]
          manufacturer = Prestashop::Mapper::Manufacturer.find_by(filter: {name: manufacturer_name})
          update = Prestashop::Mapper::Product.update(product_id, id_manufacturer: manufacturer)
          puts "Updated Product Manufacturer which was absent"

        end
        if brand != product_hash["Brand"] || brand.empty?
          manufacturer_name = product_hash["Brand"]
          manufacturer = Prestashop::Mapper::Manufacturer.find_by(filter: {name: manufacturer_name})
          update = Prestashop::Mapper::Product.update(product_id, id_manufacturer: manufacturer)       
          if update.is_a?(Hash) && !updated
            updated_products += 1
            updated = true
          end
        end
        # Find current stock level
        stock_available_id = Prestashop::Mapper::StockAvailable.find_by(filter: {id_product: product_id})
        if stock_available_id
          stock_available_object = Prestashop::Mapper::StockAvailable.find(stock_available_id)
          their_quantity_object = stock.find {|p| p[0] == product } rescue nil
          if their_quantity_object
            their_quantity = their_quantity_object[1].to_i 
            unless their_quantity == stock_available_object[:quantity]
              puts "Updating quantity from #{stock_available_object[:quantity]} to #{their_quantity}"
              update = Prestashop::Mapper::StockAvailable.update(stock_available_id, quantity: their_quantity)
              if update.is_a?(Hash) && !updated
                updated_products += 1
                updated = true
              end
            end
          end
        end
        
        Prestashop::Mapper::Product.update(product_id, ean13: product_hash["UPC"])  unless our_product_info[:ean13].to_s == product_hash["UPC"]
      rescue NoMethodError
      rescue Prestashop::Api::RequestFailed => e
        mail = Mail.new do
          from    'lesalfistes@gmail.com'
          to      't_bromehead@yahoo.fr'
          cc 'lesalfistes@gmail.com '
          subject "Erreur de modification de l'article #{product_id}"
        
          text_part do
            body "Erreur de suppression: #{e.message}"
          end
        
          html_part do
            content_type 'text/html; charset=UTF-8'
            body "<h2>L'article #{product_id} n'a pas pu être modifié, voici le détail:</h2><p>#{e.message}</p>"
          end
        end
        mail.deliver!
      end
    end
  end

  if updated_products > 1
    mail = Mail.new do
      from    'lesalfistes@gmail.com'
      to      'tom@montpellier4x4.com'
      cc 't_bromehead@yahoo.fr'
      subject "MAJ #{brand}: #{updated_products} quantités/prix/poids/UPC ou descriptions modifié(e)s"
    
      text_part do
        body "#{updated_products} articles du catalogue Front-Runner ont été mis à jour"
      end
    
      html_part do
        content_type 'text/html; charset=UTF-8'
        body "<h2>#{updated_products} articles du catalogue Front-Runner ont été mis à jour</h2>"
      end
    end
    mail.deliver!
  end
end

# our_arb = Prestashop::Mapper::Product.all(filter: { id_manufacturer: 7}, display: '[reference]').map { |h| h[:reference] } 

def update_arb_products(products)
  csv_arb = CSV.read("arb.csv").map { |(ref, rrp, desc, gtin, brand, sub_brand, weight, width_cm, depth_cm, length_cm, retail, images, attributes)| [ref, gtin, weight, width_cm, depth_cm, length_cm] }
  available_references_json = JSON.parse(File.open("arb.json").read)
  updated_products = 0
  found_products = 0
  json_arb = Hash.new
  csv_arb.shift
  csv_arb.each do |product|
    json_arb[product[0]] = {"gtin": product[1], "weight": product[2], "width": product[3], "depth": product[4], "length": product[5] }
  end
  FileUtils.touch("arb.json")
  File.open("arb.json", "w+") do |file|
    file.write(JSON.dump(json_arb))
  end
  products = products.map{|p| p.to_s }
  products.each do |product|
    product_hash = available_references_json.find do |p| 
      p[0] == product 
    end
    if product_hash.nil?
      product_hash = available_references_json.find do |p| 
        p[0].sub!("ARB-","") == product rescue nil
      end
    end
    if product_hash.nil?
      puts "#{product} is not in our system, might have to consider creating it"
      next
    else
      puts "Found product #{product}"
    end
    # Get id
    product_id = Prestashop::Mapper::Product.find_by(filter: {reference: product})
    puts "PRODUCT REF IS: #{product}"
    if product_id
      found_products += 1
    end
    if product_id
      # Get product info
      product_info = Prestashop::Mapper::Product.find(product_id)
      updated = false
      begin 
        # Check price and update if different
        # fr_price = product_hash["RetailPrice"].to_f 
        # our_price = product_info[:price].to_f
        # unless fr_price == our_price
        #   update = Prestashop::Mapper::Product.update(product_id, price: fr_price)
        #   updated = true
        #   updated_products += 1 if update.is_a?(Hash)
        # end
        weight = product_info[:weight].to_f
        puts "PRODUCT WEIGHT IS: #{weight}"
        if weight.zero? || weight != product_hash[1]["weight"]
          new_weight = product_hash[1]["weight"].to_f
          puts "Weight was #{weight} and will now be #{new_weight}" unless product_hash[1]["weight"].to_f == 0
          update = Prestashop::Mapper::Product.update(product_id, weight: new_weight) unless product_hash[1]["weight"].to_f == 0
          if update.is_a?(Hash) && ! updated
            updated_products += 1
            updated = true
          end
        end
        if product_info[:ean13].empty? || product_info[:ean13] != product_hash[1]["gtin"]
          update = Prestashop::Mapper::Product.update(product_id, ean13: product_hash[1]["gtin"]) if !product_hash[1]["gtin"].empty?
          puts "Updated EAN info: was #{product_info[:ean13]}, will be #{product_hash[1]["gtin"]}"
          if update.is_a?(Hash) && ! updated
            updated_products += 1
            updated = true
          end
          puts "Updated EAN13"
        end
        if product_info[:width].to_f.zero? || product_info[:width] != product_hash[1]["width"]
          update = Prestashop::Mapper::Product.update(product_id, width: product_hash[1]["width"]) if !product_hash[1]["width"].to_f.zero?
          puts "Updating width, was #{product_info[:width]}, will be #{product_hash[1]["width"]}"
          if update.is_a?(Hash) && ! updated
            updated_products += 1
            updated = true
          end
        end
        if product_info[:depth].to_f.zero? || product_info[:length] != product_hash[1]["length"]
          update = Prestashop::Mapper::Product.update(product_id, depth: product_hash[1]["length"]) if !product_hash[1]["length"].to_f.zero?
          puts "Updating depth/length, was #{product_info[:depth]}, will be #{product_hash[1]["length"]}"
          if update.is_a?(Hash) && ! updated
            updated_products += 1
            updated = true
          end
        end
        if product_info[:height].to_f.zero? || product_info[:height] != product_hash[1]["height"]
          update = Prestashop::Mapper::Product.update(product_id, height: product_hash[1]["depth"]) if !product_hash[1]["depth"].to_f.zero?
          puts "Updating width, was #{product_info[:height]}, will be #{product_hash[1]["height"]}"
          if update.is_a?(Hash) && ! updated
            updated_products += 1
            updated = true
          end
        end
        price_displayed = product_info[:show_price]
        if price_displayed.zero?
          # Prestashop::Mapper::Product.update(product_id, show_price: 1) 
          puts "Price will now be displayed"
        end
      rescue NoMethodError
      rescue Prestashop::Api::RequestFailed => e
        mail = Mail.new do
          from    'lesalfistes@gmail.com'
          to      't_bromehead@yahoo.fr'
          cc 'lesalfistes@gmail.com '
          subject "Erreur de modification de l'article #{product_id}"
        
          text_part do
            body "Erreur de suppression: #{e.message}"
          end
        
          html_part do
            content_type 'text/html; charset=UTF-8'
            body "<h2>L'article #{product_id} n'a pas pu être modifié, voici le détail:</h2><p>#{e.message}</p>"
          end
        end
        mail.deliver!
      end
    end
  end
  if updated_products > 1
    mail = Mail.new do
      from    'lesalfistes@gmail.com'
      to      'tom@montpellier4x4.com'
      cc 't_bromehead@yahoo.fr'
      subject "MAJ ARB: #{updated_products} produits modifiés"
    
      text_part do
        body "#{updated_products} articles du catalogue ARB ont été modifiés"
      end
    
      html_part do
        content_type 'text/html; charset=UTF-8'
        body "<p>#{updated_products} articles du catalogue ARB ont été modifiés.
          Code GTIN/EAN13/Marque ajouté(e) et ou dimensions (poids compris) modifié(e)s<p>"
      end
    end
    mail.deliver!
  end
end

def create_b2b_categories
  # Create
  categories = CSV.read("b2b-categories.csv")
  parent = Prestashop::Mapper::Category.find_by(filter: {name: "4x4Center"})
  categories.uniq.each do |c|
    # next if c["id"] == 1
    exists = Prestashop::Mapper::Category.find_by({filter: {name: c[0]}})
    unless exists
      if parent != 1
        category = Prestashop::Mapper::Category.new({name: c[0], id_lang: 1, id_parent: parent, link_rewrite: "", active: 0})
      else
        category = Prestashop::Mapper::Category.new({name: c[0], id_lang: 1, link_rewrite: "", active: 0})
      end
      new_cat = category.create
      if !!new_cat
        puts "Category was created successfully #{c[0]}"
      end
    end
  end
  # Map them
end

# def create_trans4_products(new_products)
#   created_products = 0
#   return if new_products.length < 1
#   updated_products = 0
#   new_product_info = []
#   brand  = ""
#   new_products.each do |ref|
#     build_args = Hash.new
#     # Look up product in JSON Hash
#     product_hash = available_references_json.find { |p| p["Code"] == ref }
#     next unless product_hash
#     # Check whether the product exits
#     build_args["reference"] = product_hash["Code"]
#     build_args["name"] = product_hash["Description"]
#     build_args["price"] = product_hash["RetailPrice"].to_i
#     build_args["upc"] = product_hash["UPC"].length < 13 ? product_hash["UPC"] : "" 
#     build_args["brand"] = product_hash["Brand"]
#     brand = build_args["brand"]
#     build_args["description_short"] = product_hash["Narration"]
#     build_args["description"] = product_hash["LongDescription"] + "\n\n" + product_hash["Specification"]
#     build_args["meta_title"] = "Montpellier4x4 vous propose le " + product_hash["Description"]
#     build_args["weight"] = product_hash["Weight_kg"]
#     build_args["meta_description"] = product_hash["Narration"][0...200]
#     build_args["available_for_order"], build_args["available_now"] = 1, 1
#     build_args["id_tax_rules_group"] = 9
#     build_args["show_price"] = 1
#     product = Prestashop::Mapper::Product.find_by(filter: {reference: build_args["reference"]})
#     puts "Product #{product} found " if product
#     unless product
#       # # Get id or English language
#       # Set defaults for product
#       id_lang = Prestashop::Mapper::Language.find_by_iso_code('fr')
#       build_args["id_lang"] = id_lang
#       id_manufacturer = Prestashop::Mapper::Manufacturer.find_by( filter: {name: build_args["brand"]}) rescue nil
#       unless id_manufacturer
#         # Send Warning Email that this manufacturer doesn't exist
#         # 
#       end
#       build_args.merge!({id_lang: id_lang, id_manufacturer: id_manufacturer})
#       cat_name = "#{Date.today.day} #{Date::MONTHNAMES[Date.today.month]} #{Date.today.year} Import #{build_args["brand"]}"
#       category_id = Prestashop::Mapper::Category.find_by(filter: { name: cat_name })
#       unless category_id
#         category = Prestashop::Mapper::Category.new({name: cat_name, id_lang: id_lang, link_rewrite: cat_name, active: 0})
#         new_cat = category.create
#         category_id = new_cat[:id]
#       end
#       build_args["available_for_order"], build_args["available_now"] = 1, 1
#       build_args["id_category_default"] = category_id
#       # Find weight attribute
#       weight = Prestashop::Mapper::ProductFeature.find_in_cache("Poids", id_lang)
#       weight_value = Prestashop::Mapper::ProductFeatureValue.find_in_cache(weight[:id], build_args["weight"], id_lang)
#       unless weight_value
#         temp_weight_value = Prestashop::Mapper::ProductFeatureValue.new(id_feature: weight[:id], value: build_args["weight"].to_s, id_lang: id_lang)
#         weight_value = temp_weight_value.create
#       end
#       build_args["id_features"] = [
#         ActiveSupport::HashWithIndifferentAccess.new({id_feature: weight[:id], id_feature_value: weight_value[:id]})
#       ]
#       draft_product = Prestashop::Mapper::Product.new(build_args)
#       begin
#         new_product = draft_product.create
#       rescue Prestashop::Api::RequestFailed => e
#         # Email error message
#         puts e.message
#       end
#       if new_product[:id]
#         info = "#{new_product[:id]}: #{}"
#         new_product_info  << info
#         puts "Product #{new_product[:name]} has been created"
#         created_products += 1
#         Prestashop::Mapper::Product.update(new_product[:id], state: 1, active: 1)
#         # Upload images:
#         (1..8).each do |n|
#           image = Prestashop::Mapper::Image.new(resource: :products, id_resource: new_product[:id], source: product_hash["Image_#{n}"])
#           if image
#             puts "Uploading image for product #{new_product[:id]}"
#             begin
#               uploaded = image.upload
#             rescue Prestashop::Api::RequestFailed
#             end
#           end
#         end
#       else
#         puts "Skipping this product, already exists"
#         # Product already exists
#         next
#       end
#     end
#   end
#   if created_products >= 1
#     # mail = Mail.new do
#     #   from    'lesalfistes@gmail.com'
#     #   to      'tom@montpellier4x4.com'
#     #   cc 'lesalfistes@gmail.com'
#     #   subject "Création de #{created_products} produits du catalogue #{brand}"
    
#     #   text_part do
#     #     body ""
#     #   end
    
#     #   html_part do
#     #     content_type 'text/html; charset=UTF-8'
#     #     body "Produits dans "
#     #   end
#     # end
#     # mail.deliver!
#     translate_products(new_products)
#   end

# end


# update_arb_products(our_arb)
# [cadac_hash].each { |products| update_products(products)}

# [[old_fr, old_fr_info, "Front Runner"]].each do |products|
#   delete_products(products[0], products[1], products[2]) 
# end
# [[old_dometic, old_dometic_info, "Dometic"]].each do |products|
#   delete_products(products[0], products[1], products[2]) 
# end
begin
  [their_fr].each { |products| update_front_runner_products(products)}
  [front_runner_hash].each { |products| update_front_runner_products(products)}
  # [their_fr].each { |products| update_front_runner_products(products)}
  [available_references_csv].each { |products| update_front_runner_products(products)}
  [new_fr].each { |products| create_front_runner_products(products, "FR")}
rescue
ensure
  Dir["*.csv"]
end

# [new_dometic].each { |products| create_front_runner_products(products, nil, true) }
#  dometic_not_yet_on_site = Prestashop::Mapper::Product.all(filter: {id_category_default: 3031})
# [dometic_not_yet_on_site].each { |products| translate_products(products, "EN")}
# [front_runner_hash].each { |products| translate_products(products)}
# [petromax_hash].each { |products| translate_products(products)}
# 
# Update state or product for it to be displayed, for some reason it's not in the creation XML

# create_b2b_categories