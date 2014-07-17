class ExcludedTaxaFileParser
  attr_reader :data, :valid_format, :error, :taxa_list
  
  def initialize(stream, taxa_file)
    @filename = ""
    @data = []
    @valid_format = true
    @error = ""

    @taxa_list = File.open(taxa_file, "r").readlines

    if stream.instance_of?(String) # because of testing
      if stream =~ /\S+\/(\w+\.ex)$/
        @filename = $1
      end
      @data = File.open(stream,'r').readlines      
    else
      @filename = stream.original_filename
      @data = stream.readlines      
    end
    checkFormat
  end

  private
  def checkFormat
    for i in 0..@data.size-1
      line = @data[i]
      if line =~ /^\s*$/
        @error = "Error in #{@filename} line #{i+1}! Empty lines are not allowed.\n\n" 
        @valid_format = false
        break
      elsif line =~ /^\S+\s+\S+$/
        @error = "Error in #{@filename} line #{i+1}! Taxon has to be one word.\n\n"
        @valid_format = false
        break
      elsif !(line =~ /^\S+$/)
        @error = "Error in #{@filename} line #{i+1}!\n\n"
        @valid_format = false
        break
      elsif ! @taxa_list.include?(line)
        @error = "Error in #{@filename} line #{i+1}!\n\n #{line} is not a taxon that occursr in the bootstrap file you uploaded. \nIf you want certain taxa not to be considered as rogues, you do not have to specify this here\nbutb can do so manually on the next screen."
        @valid_format = false
        break
      end
    end
  end
end

