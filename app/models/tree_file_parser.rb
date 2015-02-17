require 'pty'

class TreeFileParser
  
attr_reader :format, :valid_format, :error ,:data
  def initialize(stream)
    @filename = ""
    @data=[]
    if stream.instance_of?(String) # because of testing
      if stream =~ /\S+\/(\w+\.newick)$/ || stream =~ /\S+\/(\w+\.bts)$/
        @filename = $1
      end
      @data = File.open(stream,'r').readlines
    else
      @filename =stream.original_filename
      @data = stream.readlines 
    end
    @format = "unk"
    @valid_format = false
    @error = ""
    @message = "has errors in #{@filename}"
    checkFormat   
  end

  private
  def getJobDir(jobid)
    jobs_path = File.join( RAILS_ROOT, "public", "jobs")
    if not APP_CONFIG['pbs_job_folder'].empty?
      jobs_path = APP_CONFIG['pbs_job_folder']
    end
    path = File.join( jobs_path, jobid)
    return path
  end

  private
  def checkFormat
    @valid_format = true
    @format = "tree"
    checkTreefileFormatWithJava
  end

  private
  def checkTreefileFormatWithJava
    random_number = (1+rand(10000))* (1+(10000%(1+rand(10000))))*(1+rand(10000))    #build random number for @filename to avoid collision
    file = "#{RAILS_ROOT}/tmp/files/#{random_number}_#{@filename}" 
    f = File.open(file,'wb')
    @data.each {|d| f.write(d)}
    f.close
    cmd = "java -jar " + File.join( RAILS_ROOT, "bioprogs", "java", "treecheck.jar") + " #{file}"
    # let treecheck.jar check if newick format is correct
    PTY.spawn(cmd) do |stdin, stdout, pid| 
      
      stdin.each do  |line| 
        if !(line =~ /good/)
          @error = @error+line
          @format = "unk"
          @valid_format = false
        end
      end
    end rescue Errno::EIO
    if !@error.eql?("")
      @error = "#{@message}\n#{@error}\n"
    end
    system "rm #{file}"
  end
  
  public 
  def buildTaxaFile(jobid, treefile_on_disk)
    outfile = File.join( getJobDir(jobid), "taxa_file")
    cmd = "java -jar " + File.join( RAILS_ROOT, "bioprogs", "java", "extract_tree_taxa.jar") + " #{treefile_on_disk} #{outfile}"
    PTY.spawn(cmd) do |stdin, stdout, pid| 
      
      stdin.each do  |line| 
        if !(line =~ /good/)
          @error = @error+line
          @valid_format = false
        end
      end
    end rescue Errno::EIO
    if !@error.eql?("")
      @error = "#{@message}\n#{@error}\n"
    end
    return outfile
  end
end
