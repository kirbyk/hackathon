class VisualizationController < ApplicationController
	skip_before_action :require_login
	layout false
  def index
  	@school_info = Hash.new
  	Hacker.all.each do |hacker|
      if hacker.school_id
      	@school = School.find_by(id: hacker.school_id)
        if @school.lat == nil or @school.lng == nil
          @test = getCoordinates(hacker.school_id)
        end
        if @school_info[@school.name] == nil
          @school_info[@school.name] = [1, @school.lat, @school.lng, @school.state]
        else
           @count = @school_info[@school.name][0] + 1
           @school_info[@school.name] = [@count, @school.lat, @school.lng, @school.state]
        end
 	  end
  	end
  end

  def getCoordinates (school_id)
    @school = School.find school_id
    formatted_name = @school.name.gsub(/\s+/,'+')
    response = Net::HTTP.get_response(URI.parse("http://maps.googleapis.com/maps/api/geocode/json?address=#{formatted_name}"))
    parsed = JSON.parse(response.body)
    @school.lat = parsed['results'][0]['geometry']['location']['lat']
    @school.lng = parsed['results'][0]['geometry']['location']['lng']
    @school.save
  end
end