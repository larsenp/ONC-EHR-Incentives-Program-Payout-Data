namespace :hospitals do
  SOCRATA_APP_TOKEN = "c1qN0TO6e65zh9oxVD6XrVJyT"

  task :ensure_fields_are_properly_formatted do
    Hospital.all.each do |h|
      h.update_attribute("PROVIDER CCN",format_ccn(h["PROVIDER CCN"]))
      h.update_attribute("PROVIDER ZIP 5 CD",add_leading_zeros(h["PROVIDER ZIP 5 CD"],5))
      h.update_attribute("PROVIDER ZIP 4 CD",add_leading_zeros(h["PROVIDER ZIP 4 CD"],4)) unless h["PROVIDER ZIP 4 CD"].to_s.length == 0
      h.rename(:"PROVIDER / ORG NAME",:"PROVIDER - ORG NAME") # rename field so it is mongoexport-able
    end
  end


  desc "Add General Hospital Info to datastore if they are not already in it"
  task :ingest_general_info do
    puts "#{Hospital.count} hospitals in db"

    socrata_endpoint = "http://data.medicare.gov/resource/v287-28n3.json"
    all_hospitals = fetch_whole_socrata_dataset(socrata_endpoint, SOCRATA_APP_TOKEN)

    puts "Ingesting new data"
    all_hospitals.each do |general_row|
      new_general_data = {
        "_source" => socrata_endpoint,
        "_updated_at" => Time.now,
      }.merge(general_row)
      h = Hospital.find_by("PROVIDER CCN" => format_ccn(new_general_data["provider_number"]))
      if h.nil?
        Hospital.create("general" => new_general_data, "PROVIDER CCN" => format_ccn(new_general_data["provider_number"]))
      else
        h.update_attributes("general" => new_general_data)
      end
    end
    puts "#{Hospital.count} hospitals in db"
  end


  desc "Fetch HCAHPS hospital data from Socrata API for hospitals that are already in our system (aka received incentive payments)"
  task :ingest_hcahps do
    socrata_endpoint = "http://data.medicare.gov/resource/rj76-22dk.json"

    puts "Number of hospitals in collection: #{Hospital.count}"
    hospitals_without_hcahps = Hospital.without_hcahps
    puts "Number of hospitals in collection w/o HCAHPS: #{hospitals_without_hcahps.count}"

    hcahps_data = fetch_whole_socrata_dataset(socrata_endpoint, SOCRATA_APP_TOKEN)

    puts "Ingesting new data"
    hcahps_data.each do |hcahps_row|
      new_hcahps_data = {
        "_source" => socrata_endpoint,
        "_updated_at" => Time.now,
      }.merge(hcahps_row)
      h = Hospital.find_by("PROVIDER CCN" => format_ccn(new_hcahps_data["provider_number"]))
      if h.nil?
        Hospital.create("hcahps" => new_hcahps_data, "PROVIDER CCN" => format_ccn(new_hcahps_data["provider_number"]))
      else
        h.update_attribute("hcahps",new_hcahps_data)
      end
    end
    
    puts "#{Hospital.count} hospitals in db"
    puts "Number of hospitals in collection w/o HCAHPS: #{Hospital.without_hcahps.count}"
  end

  #desc "Calculate HCAHPS national averages for each value and store in a hcahps_averages collection"
  #task :calculate_national_averages do
  #  # find out what fields we need to calculate averages for
  #  array_of_fields = Hospital.where("hcahps" => {"$ne" => nil}).first["hcahps"].keys
  #  array_of_fields.each do |field|
  #    Hospital.mr_compute_descriptive_stats_excluding_nulls("hcahps.#{field}")
  #  end
  #end

  task :simple_report do
    puts "\nWe started by analyzing hospitals that received incentive payments in program year 2011, 2012, or 2013. We then added all hospitals in the hospital compare (general information) data set, and added HCAHPS data for as many hospitals as we could, using their CCN as the look-up variable.\n\n"
    # Documents with a root-level key of "PROGRAM YEAR 2012" DID receive incentive payments
    puts "  # received an incentive* (* in any of 2011, 2012, _or_ 2013) = #{Hospital.received_any_incentives.count}"
    puts "    # received an incentive* and we were able to geocode = #{Hospital.received_any_incentives.with_geo.count}"
    puts "    # received an incentive* and we found HCAHPS data = #{Hospital.received_any_incentives.with_hcahps.count}"
    puts "    # received an incentive* and we found general information = #{Hospital.received_any_incentives.with_general.count}"
    puts " -> # received an incentive* and we found general information, HCAHPS, and geocoded = #{Hospital.received_any_incentives.with_general.with_hcahps.with_geo.count} (#{(Hospital.received_any_incentives.with_general.with_hcahps.with_geo.count/Hospital.received_any_incentives.count.to_f*100).round}% of ones that received incentives) \n\n"
    puts "  # did not received an incentive*  = #{Hospital.never_received_any_incentives.count}"
    puts "    # did not received an incentive* and we were able to geocode = #{Hospital.never_received_any_incentives.with_geo.count}"
    puts "    # did not received an incentive* and we found HCAHPS data = #{Hospital.never_received_any_incentives.with_hcahps.count}"
    puts "    # did not received an incentive* and we found general information = #{Hospital.never_received_any_incentives.with_general.count} \n\n"

    puts "TOTAL HOSPITALS IN DB = #{Hospital.count} (# received any incentives* + # never received an incentive)\n\n"

  end


end
