require 'digest/md5'
require 'fileutils'
require 'enumerator'

class RoguenarokController < ApplicationController
  
  @fileName = nil
  @jobName = nil

  def index
    @job = Roguenarok.new
    @user = User.new
    render :action => 'submit'
  end

  def submit
    @job = Roguenarok.new
    @user = User.new
  end

  ###################################################################################
  ### UPLOAD VIEW

  def upload
    ############################################################################
    ### collect parameters and set default values for optional ones if they are nil
    bootstrap_treeset_file = nil
    if !params[:bootstrap_tree_set].nil?
      bootstrap_treeset_file = params[:bootstrap_tree_set][:file]
    end
    best_known_tree_file = ""
    if  !params[:best_known_tree].nil?
      best_known_tree_file = params[:best_known_tree][:file]
    end

    taxa_to_exclude_file = nil
    if  !params[:taxa_to_exclude].nil?
      taxa_to_exclude_file = params[:taxa_to_exclude][:file]
    end

    description = ""
    if !params[:description].nil?
      description = params[:description]
    end

    email = ""
    if !params[:email].nil?
      email = params[:email][:email_address]
    end

    ## get user IP and generate possible job id
    ip = request.remote_ip
    jobid = generateJobID
    
    ###################
    ### save user infos 
    if ip.eql?("") || ip.nil?
      ip = "xxx.xxx.xxx.xxx"
    end

    if User.exists?(:ip => ip)
      @user = User.find(:first, :conditions => {:ip => ip})
      @user.update_attributes(:email => email)
    else
      @user = User.new({:email => email, :ip => ip, :saved_subs => 0, :all_subs => 0})
      @user.save      
    end

    #################
    ### save job data & update user submission counter if everything is alright

    @job = Roguenarok.new({:jobid => jobid, :user_id => @user.id, :description => description, :bootstrap_tree_set => bootstrap_treeset_file, :tree => best_known_tree_file , :excluded_taxa => taxa_to_exclude_file})
    buildJobDir(jobid)
    if @job.valid? && @user.errors.size < 1
      @job.save
      @user.update_attribute(:saved_subs, @user.saved_subs+1)
      @user.update_attribute(:all_subs, @user.all_subs+1)
      counter_ip = "c.c.c.c"
      if User.exists?(:ip => counter_ip)
        user_counter = User.find(:first, :conditions => {:ip => counter_ip })
        user_counter.update_attribute(:saved_subs, user_counter.saved_subs+1)
        user_counter.update_attribute(:all_subs, user_counter.all_subs+1)
      else
        user_counter = User.new({:ip => counter_ip, :saved_subs => 1, :all_subs => 1})
        user_counter.save
      end

      dummySearch = Search.new({:jobid => jobid, :name => "dummy" , :filename => ""  })
      dummySearch.save 
      taxa = File.open(@job.taxa_file, 'rb').readlines

      taxa.sort! {|x,y| x <=> y} 

      cnt = 1 
      taxa.each do |t|        
        taxon = Taxon.new({:roguenarok_id => jobid, :name => t.chomp!, :search_id => dummySearch.id, :pos => cnt})
        cnt += 1 
        taxon.save
      end

      @fileName = nil
      @jobName = nil
      
      if !taxa_to_exclude_file.nil?  && !taxa_to_exclude_file.eql?("")
        ex_taxa = File.open(@job.excluded_taxa, 'rb').readlines
        @job.excludeTaxa(jobid, ex_taxa)
      end
      redirect_to :action => 'work', :jobid => jobid 
    else
      destroyJobDir(jobid)
      @job.errors.each do |field,error|
        puts field
        puts error
      end

      @user.errors.each do |field,error|
        puts field
        puts error
      end
      render  :action => 'submit'
    end 
  end

  def annotatePhyFile(phyFile, namefile)
    names = File.open(namefile).readlines.map{|name| name.chomp!}.reverse
    fh = File.open(phyFile, "r")
    content = fh.readline
    fh.close
    
    pattern = /(<phyloge[^>]+>)/
    indices = content.enum_for(:scan, pattern).map {Regexp.last_match.end(0)}.reverse
    
    i = 0
    raise "not enough names available!" unless indices.length == names.length 
    indices.each do  |index|
      content = content.insert(index, "<name>#{names[i]}</name>")
      i += 1
    end

    # puts content
    fh = File.open(phyFile, "w")
    fh.write(content)
    fh.close
  end

  
  def deleteSuperfluousFiles(path)
    files = Dir.glob(File.join(path,"*"))

    fileHash = {}
    files.each do |file|    
      digest = Digest::MD5.hexdigest(File.read(file))
      
      if ! fileHash.has_key?(digest)
        fileHash[digest] = file
      else
        
        otherFile = fileHash[digest]
        
        # delete older file 
        endingOther = otherFile.split("_")[-1].to_i
        endingHere = file.split("_")[-1].to_i

        if endingOther > endingHere
          FileUtils.rm_rf(file) 
        else
          FileUtils.rm_rf(otherFile)
          fileHash[digest] = file
        end 
      end
    end  
  end
  
  def getIdFromButton(params)    
    theSearch = params.keys.select{ |k| k =~ /[\._]x/}[0]
    myMatch = theSearch.match(/.+@([0-9]+).[xy]/)
    
    raise "Your browser submits data differently than expected. Please report the browser version you encountered this problem with." if myMatch.nil?
    theSearch = myMatch[1].to_i
    return theSearch
  end

  def initializeTreeViewer(params)
    result = ""
    @jobid = params[:jobid]
    
    if !params.has_key?("display")
      return result
    end

    jobPath = getJobDir( @jobid)

    # remove duplicate file 
    deleteSuperfluousFiles( File.join( jobPath, "display") )
    
    # concatenate all trees  
    Rails.logger.info( "#{@jobid}: concatenate all trees to #{jobPath}/display_tree and add list to #{jobPath}/phyloNames")
    system "cat $(ls -tr #{jobPath}/display/*) | head -n 10  > #{jobPath}/display_tree"
    system "ls -tr #{jobPath}/display/ > #{jobPath}/phyloNames"
    
    Rails.logger.info( "#{@jobid}: preparing #{jobPath}/display_tree.xml")
    system "rm -f #{jobPath}/display_tree.xml"
    system "java -cp #{RAILS_ROOT}/bioprogs/java/forester.jar org.forester.application.phyloxml_converter -f=nn #{jobPath}/display_tree  #{jobPath}/display_tree.xml"
    
    system "tr -d '\n' < #{jobPath}/display_tree.xml | sed 's/>[ ]*</></g' > #{jobPath}/tmp"
    system "mv #{jobPath}/tmp #{jobPath}/display_tree.xml"

    annotatePhyFile(File.join(jobPath,"display_tree.xml"),File.join(jobPath,"phyloNames"))


    system "cp #{RAILS_ROOT}/public/applets/config_file #{jobPath}" 
    confFileHandle = File.open("#{jobPath}/config_file", "a")
    id = 1
    
    if File.exists?(jobPath + "pruned_taxa")
      pruned_taxa =  File.open(File.join(jobPath, "pruned_taxa")).readlines

      pruned_taxa.each do |taxon| 
        taxon.chomp!
        
        tmp = id.to_s.rjust(8, "0")
        confFileHandle.write("species_color: #{tmp} 0xFF0000\n")

        system "sed 's/\\(<name>#{taxon}<\\/name><branch_length>[0-9\\.]*<\\/branch_length>\\)/\\1<taxonomy><code>#{tmp}<\\/code><\\/taxonomy>/g' #{jobPath}/display_tree.xml > #{jobPath}/tmp"
        system "mv #{jobPath}/tmp #{jobPath}/display_tree.xml" 

        system "sed 's/\\(<name>#{taxon}<\\/name>\\)\\(<[^b][^r][^a]\\)/\\1<taxonomy><code>#{tmp}<\\/code><\\/taxonomy>\\2/g' #{jobPath}/display_tree.xml > #{jobPath}/tmp"
        system "mv #{jobPath}/tmp #{jobPath}/display_tree.xml" 
        
        id += 1 
      end
      
      # @curTreeInfo = calculateRbic(File.join(["#{jobPath}", "current_tree"]), 
      #                              pruned_taxa.length,
      #                              File.open("#{jobPath}/taxa_file", "r").readlines.length
      #                              )

    end
    confFileHandle.close()

#     tree_file = "http://#{ENV['SERVER_IP']}:8080/rnr/jobs/#{@jobid}/display_tree.xml"
#     config_file = "http://#{ENV['SERVER_IP']}:8080/rnr/jobs/#{@jobid}/config_file"

#     tree_file = "http://#{ENV['SERVER_IP']}/rnr/jobs/#{@jobid}/display_tree.xml"
#     config_file = "http://#{ENV['SERVER_IP']}/rnr/jobs/#{@jobid}/config_file"

    tree_file = "http://rnr.h-its.org/rnr/jobs/#{@jobid}/display_tree.xml"
    config_file = "http://rnr.h-its.org/rnr/jobs/#{@jobid}/config_file"
    Rails.logger.info( "#{@jobid}: tree_file at #{tree_file}")
    Rails.logger.info( "#{@jobid}: config_file at #{config_file}")

#     file = File.open("/rnr/jobs/#{@jobid}/display_tree.xml", "w")

    fileA = File.join( jobPath, "display_tree.xml")
    fileB = File.join( jobPath, "config_file")
    
    File.chmod( 0755, fileA )
    File.chmod( 0755, fileB )
    File.chmod( 0755, jobPath)
#     file = File.new("/rnr/jobs/#{@jobid}/config_file", "w")
#     File.chmod(0755, "/rnr/jobs/#{@jobid}/config_file")

#     File.chmod(755, tree_file)
#     File.chmod(755, config_file)
    
    # call tree viewer
    result = "\n<SCRIPT> $(document).ready(function(){openWin('#{tree_file}','#{config_file}');});</SCRIPT>\n"
    Rails.logger.info( "#{@jobid}: result #{result}")

    return result
  end

  #######################################################################
  ### WORKFLOW VIEW ####

  def work
    @jobid = params[:jobid]

    # check if job with this id exists
    rog = Roguenarok.find(:first, :conditions => {:jobid => @jobid})
    if rog == nil
      raise ActionController::RoutingError.new('job not found')
    end

    job_path = getJobDir( @jobid)
    path     = File.join( job_path  , "results")

    #### CHECK WHICH SUBMISSION HAS TO BE PERFORMED
    jobtype = params[:jobtype]
    @job = nil    
    
    Rails.logger.info( "initializeTreeViewer")
    @loadTreeViewer = initializeTreeViewer(params)
    
    ### Taxa Analysis
    Rails.logger.info( "#{@jobid} jobtype: #{jobtype}")
    case jobtype 
    when "analysis"
      updateCheckedTaxa(@jobid, [])
      
      Rails.logger.info( "#{@jobid}: taxa_analysis: #{params[:taxa_analysis]}")
      
      tmp = rogueTaxaAnalysis(params) if params[:taxa_analysis].eql?("RogueNaRok" )
      tmp = lsiAnalysis(params) if params[:taxa_analysis].eql?("leaf stability index" )
      tmp = tiiAnalysis(params) if params[:taxa_analysis].eql?("taxonomic instability index" )
      
      if tmp.class == Hash
        currentJob = Roguenarok.find(:first, :conditions => {:jobid => @jobid})
        currentJob.update_attribute(:searchname,  tmp[:jobName])
        currentJob.update_attribute(:filetoparse, tmp[:fileName])
        
        if tmp.has_key?(:mode)  # for lsi 
          currentJob.update_attribute(:modes, tmp[:mode].join(",")) 
        end
        redirect_to :action => 'wait', :jobid => @jobid
      else        
        @job = tmp 
      end

    when "include"
      updateCheckedTaxa(@jobid, [])
      includeTaxa(params)
    when "treeManipulation" 
      updateCheckedTaxa(@jobid, []) if params.keys.any?{|k| k =~ /saveSearch/ || k =~ /deleteSearch/ || k =~ /sortSearch/}
      job = Roguenarok.find(:first, :conditions => {:jobid => @jobid})
      
      if params.keys.any? { |k| k =~ /saveSearch/ } 
        theSearch = getIdFromButton(params) 
        s = Search.find(:first, :conditions => {:id => theSearch})
        send_file s.filename
      end 
      
      if params.keys.any? { |k| k =~ /sortSearch@dummy/ }
        s = Search.find(:first, :conditions => {:jobid => @jobid, :name => "dummy"})

        job.update_attribute(:sortedby, s.id )         
      elsif params.keys.any?{|k| k=~ /sortSearch/}
        theSearch = getIdFromButton(params)
        job.update_attribute(:sortedby,  theSearch) 
      end
      
      if params.keys.any?{ |k| k =~ /deleteSearch/ }
        theSearch = getIdFromButton(params)
        deleteSearch(theSearch)
        s = Search.find(:last, :conditions => {:jobid => @jobid})
        job.update_attribute(:sortedby, s.id)
      end

      if params[:tree_manipulation].eql?("Ignore Selected Taxa")
        excludeTaxa(params)
      elsif params[:tree_manipulation].eql?("Prune Taxa / Visualize") &&  ! params.keys.any?{|k| k =~ /saveSearch/ || k =~ /deleteSearch/ || k =~ /sortSearch/}
        tmp = prune(params)
        if tmp.nil? 
          redirect_to :action => 'wait', :jobid => @jobid
        else
          @job = tmp
        end
      end
    end

    #### INITIALIZE VARIABLES FOR THE FORM. KEEP OLD SELECTIONS WHEN AN ERROR OCCURRED.
    job = Roguenarok.find(:first, :conditions => {:jobid => @jobid })

    ### Initialize Job Description
    @description = job.description
    if @description.nil? || @description.empty?
      @description = "none"
    end
    
    currentSearchName = ""
    if ! job.nil? && ! job.sortedby.nil?
      s = Search.find(:first, :conditions => {:id => job.sortedby} )
      currentSearchName = s.name 
    end

    threshold = params[:threshold]
    @strict = false
    @mr = false
    @mre = false
    @user_def = false
    @user_def_value = nil
    @bipartitions = false
    @best_tree_available = !File.exists?( File.join( getJobDir( @jobid), "best_tree"))

    ### Initialize Threshold Selection
    if currentSearchName.eql?("") || currentSearchName =~ /_mr_/
      @mr = true
    elsif currentSearchName =~ /_strict_/
      @strict = true
    elsif m = /rnr_(\d+)_/.match(currentSearchName)
      @user_def = true
      @user_def_value = m[1]
    elsif currentSearchName =~ /_mre_/
      @mre = true
    elsif  currentSearchName =~ /_mle_/
      @bipartitions = true  
    else
      @mr = true
    end    

    ### Initialize Optimization Selection

    @support = false
    @numb_bipart = false  
    
    if params.has_key?(:optimize)
      @numb_bipart = true if  params[:optimize].eql?("number_of_bipartitions")
    elsif  currentSearchName =~ /bip$/
        @numb_bipart = true 
    else
      @support = true 
    end
    
    ### Initialize dropset value
    if params.has_key?(:dropset)      
      @dropset = params[:dropset]
    elsif  currentSearchName =~ /rnr_/
      @dropset = currentSearchName.split("_")[2].to_i
    else
      @dropset = 1 
    end

    ### Initialize excluded taxa 
    @ex_taxa = []

    search = Search.find(:first, :conditions => {:jobid => @jobid}) 
    ex_taxa = Taxon.find(:all, :conditions => { :roguenarok_id => @jobid , :search_id => search.id , :excluded => "T"})
    
    ### Initialize current tree
    @current_tree = nil
    if File.exists?(File.join(job_path,"current_tree"))
      @current_tree = File.open(File.join(job_path,"current_tree"),'r').readlines.join
      
      @curTreeInfo = calculateRbic(File.join(["#{job_path}", "current_tree"]), 
                                   File.open("#{job_path}/pruned_taxa", "r").readlines.length, 
                                   File.open("#{job_path}/taxa_file", "r").readlines.length
                                   )
    end

    # generate table of excluded taxa 
    @ex_taxa = []
    ex_taxa.each do |t|
      @ex_taxa.push(t)
    end
    
    ### Initialize Taxa Analysis Options
    @taxa_analysis_options = "";
    roguenarok = "RogueNaRok"
    lsi        = "leaf stability index"
    tii        = "taxonomic instability index"

    rougenarok_option = "<option>#{roguenarok}</option>"
    lsi_option        = "<option>#{lsi}</option>"
    tii_option        = "<option>#{tii}</option>"
    
    if params[:taxon_analysis].eql?(roguenarok)
      rougenarok_option = "<option selected=\"selected\">#{rougenarok}</option>"
    elsif params[:taxon_analysis].eql?(lsi)
      lsi_option = "<option selected=\"selected\">#{lsi}</option>"
    elsif params[:taxon_analysis].eql?(tii)
      tii_option = "<option selected=\"selected\">#{tii}</option>"
    end
    @taxa_analysis_options = rougenarok_option+lsi_option+tii_option

    ### Initialize Tree Manipulation Options
    @tree_manipulation_options = "";
    exclude_taxa = "Ignore Selected Taxa"
    prune_taxa = "Prune Taxa / Visualize"
    
    exclude_taxa_option =  "<option>#{exclude_taxa}</option>"
    prune_taxa_option = "<option>#{prune_taxa}</option>"

    job = Roguenarok.find(:first, :conditions => {:jobid => @jobid})
    @isPruning = job.ispruning

    if ! @isPruning
      exclude_taxa_option = "<option selected=\"selected\">#{exclude_taxa}</option>"
    else
      prune_taxa_option = "<option selected=\"selected\">#{prune_taxa}</option>"
    end

    @tree_manipulation_options = exclude_taxa_option+prune_taxa_option
    
    ### Initialize Taxa Listing
    prepareForTaxaTable(@jobid)
  end

  def updateCheckedTaxa(jobid, list)
    s = Search.find(:first, :conditions => {:jobid => jobid, :name => "dummy" })
    taxa = Taxon.find(:all, :conditions => {:search_id => s.id})
    taxa.each do |t| 
      t.update_attribute(:isChecked, list.include?(t.name ))
    end 
  end

  def rogueTaxaAnalysis(params)
    ### Collect parameters for Rogue Taxa Analysis and try to save them
    jobid = params[:jobid]
    threshold = params[:threshold]
    user_def = 1
    user_def = params[:threshold_user_defined] if threshold.eql?("user")

    optimize = params[:optimize]
    dropset = params[:dropset]
    job = RogueTaxaAnalysis.new({:jobid => jobid, :threshold => threshold, :user_def => user_def, :optimize => optimize, :dropset => dropset})

    ### If the input parameters have passed the validation, execute and return true
    if job.valid?
      job.save
      name = job.getName
      file = job.getFile

      link = url_for :controller => 'roguenarok', :action => 'work', :id => jobid

      job.execute(link)
      return {:fileName => file, :jobName => name}
    else
      job.errors.each do |field,error|
        puts field
        puts error
      end
      return job
    end
  end

  def includeTaxa(params)
    job = Roguenarok.find(:first, :conditions => {:jobid => params[:jobid]})
    list = []
    if !params[:extaxa].nil?
      params[:extaxa].each do |box|
        no = box[0]
        value = box[1]
        if value.size > 1 #if checkbox is unchecked the value is "0"
          list << value
        end
      end
    end
    job.includeTaxa(params[:jobid], list)
  end

  def excludeTaxa(params)
    job = Roguenarok.find(:first, :conditions => {:jobid => params[:jobid]})
    job.update_attribute(:ispruning, false)
    list = []
    if !params[:taxa].nil?
      params[:taxa].each do |box|
        no = box[0]
        value = box[1]
        if value.size > 1 #if checkbox is unchecked the value is "0"
          list << value
        end
      end
    end
    job.excludeTaxa(params[:jobid],list)
  end

  def deleteSearch(id)
    s = Search.find(:first, :conditions => {:id => id})
    Taxon.delete_all("search_id = #{s.id}") 
    s.delete    
  end

  def prune(params)   
    ### Collect parameters for pruning and try to save them
    jobid = params[:jobid]
    threshold = params[:threshold_prune]

    r = Roguenarok.find(:first, :conditions => {:jobid => jobid})
    r.update_attribute(:ispruning, true)

    user_def = 1
    if threshold.eql?("user")
      user_def = params[:threshold_prune_user_defined]
    end
    job = Pruning.new({:jobid => jobid, :threshold => threshold, :user_def => user_def})

    ### If the input parameters have passed the validation, execute and return true
    if job.valid?
      job.save
      link = url_for :controller => 'roguenarok', :action => 'work', :id => jobid

      # collect taxa that have been selected
      list = []
      if !params[:taxa].nil?
        params[:taxa].each do |box|
          no = box[0]
          value = box[1]
          if value.size > 1 #if checkbox is unchecked the value is "0"
            list << value
          end
        end
      end

      updateCheckedTaxa(jobid, list)
      job.execute(link,list)
      r.update_attribute(:display_path, job.getDisplayFileName)
      return nil
    else
      job.errors.each do |field,error|
        puts field
        puts error
      end
      return job
    end
  end

  def tiiAnalysis(params)
    jobid = params[:jobid]
    job = TiiAnalysis.new({:jobid => jobid})

    ### If the input parameters have passed the validation, execute and return true
    if job.valid?
      job.save
      name = job.getName
      file = job.getFile

      link = url_for :controller => 'roguenarork', :action => 'work', :id => jobid
      job.execute(link)
      return {:fileName => file, :jobName => name}
    else
      job.errors.each do |field,error|
        puts field
        puts error
      end
      return job
    end
  end

  def lsiAnalysis(params)
    ### Collect parameters for Rogue Taxa Analysis and try to save them
    jobid = params[:jobid]
    dif = nil
    ent = nil
    max = nil
    if !params[:lsi].nil?
      params[:lsi].each do |box|
        if box[0].eql?("dif")
          dif = box[1]
        elsif box[0].eql?("ent")
          ent = box[1]
        elsif box[0].eql?("max")
          max = box[1]
        end
      end
    end

    job = LsiAnalysis.new({:jobid => jobid, :dif => dif, :ent => ent, :max => max})

    ### If the input parameters have passed the validation, execute and return true
    if job.valid?
      job.save

      name = job.getName
      file = job.getFile

      link = url_for :controller => 'roguenarork', :action => 'work', :id => jobid 
      job.execute(link)

      return {:fileName => file, :jobName => name, :mode => [dif, ent, max] }
    else
      job.errors.each do |field,error|
        puts field
        puts error
      end      
      return job
    end    
  end


  def calculateRbic(currentTreeFile, numberExcluded, numberOfTaxa)
    fh = File.open(currentTreeFile)
    tree = fh.readline
    fh.close
    
    result = tree.scan(/\[(\d+)\]/).map{ |v| v[0].to_f}.reduce(0) do |sum, value|
      sum +  value
    end

    numBip = tree.scan(/\[(\d+)\]/).map{|v| v[0]}.length
    
    result /= (100 * (numberOfTaxa - 3 )  )
    logger.warn "\n\n" +  result.to_s
    
    result = sprintf("%0.3f", result)   

    possible = numberOfTaxa - 3 
    
    return [numberExcluded, numBip, possible, result]
#     return "excluded: #{numberExcluded}&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
# #bipartitions: #{numBip}/#{possible}&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\
# RBIC: #{result}"  
  end


  def wait
    @jobid = params[:jobid] 
    searchWasParsed = false 

    if !(jobIsFinished?(@jobid))
      render :action => 'wait' ,:jobid => @jobid
    else      
      job = Roguenarok.find(:first, :conditions =>{:jobid => @jobid})
      
      fileName = job.filetoparse
      jobName = job.searchname

      # there is something to parse 
      if  ! fileName.nil? 
        if job.modes =~ /DIF/ || job.modes =~ /ENT/ || job.modes =~ /MAX/ 
          # create multiple search instances for a lsi analysis
          if job.modes =~ /MAX/
            s = Search.new({:jobid =>  @jobid, :name => jobName + "_max", :filename => fileName})
            s.mode = :max
            s.save
            s.parseResult 
            @sortedby = s.id 
            searchWasParsed = true 
          end

          if job.modes =~ /ENT/
            s = Search.new({:jobid =>  @jobid, :name => jobName + "_ent", :filename => fileName})
            s.mode = :ent
            s.save
            s.parseResult
            @sortedby = s.id
            searchWasParsed = true 
          end

          if job.modes =~ /DIF/
            s = Search.new({:jobid =>  @jobid, :name => jobName + "_dif", :filename => fileName})
            s.mode = :dif
            s.save
            s.parseResult
            @sortedby = s.id
            searchWasParsed = true 
          end

        else
          s = Search.new({:jobid =>  @jobid, :name => jobName, :filename => fileName})
          s.save
          s.parseResult
          @sortedby = s.id
          searchWasParsed = true 
        end 
      end
      
      # sort by the search, we last parsed        
      if searchWasParsed
        job.update_attribute(:sortedby,  @sortedby) 
        job.update_attribute(:filetoparse, nil)
        job.update_attribute(:searchname, nil)
        job.update_attribute(:modes, nil) 
        job.update_attribute(:ispruning, true)
      end

      if ! job.display_path.nil?
        job.update_attribute(:display_path, nil)
        redirect_to :action => 'work', :jobid => @jobid, :display => "true"
      else
        redirect_to :action => 'work', :jobid => @jobid
      end      
      
    end
  end

  def look
    @error_id = ""
    @error_email = ""
    if !(params[:jobid].nil?)
      @error_id = "The job  with the id \'#{params[:jobid]}\' does not exist."
    elsif !(params[:email].nil?) && !(params[:email].eql?("\'\'"))
      @error_email = "No jobs for \'#{params[:email]}\' available!"
    end
  end

  def listJobs
    jobs_email = params[:email_address][:email]
    
    jobid = params[:job_id][:id]
    puts jobid
    puts jobs_email
    if jobs_email.nil? || jobs_email.empty?
      if Roguenarok.exists?(:jobid => jobid)
        redirect_to :action => "wait" , :jobid => jobid
      else
        redirect_to :action => "look" ,:jobid => jobid
      end 
    else
      job_exists = false;
      if User.exists?(:email => jobs_email) && (!jobs_email.eql?(""))
        user = User.find(:all , :conditions => {:email => jobs_email})
        user.each do |u|
          if Roguenarok.exists?(:user_id => u.id)
            job_exists = true;
            break;
          end
        end
      end

      if job_exists
        redirect_to :action => "allJobs" , :email =>  "\'#{jobs_email}\'"
      else
        redirect_to :action => "look" ,:email => "\'#{jobs_email}\'"
      end
    end
  end

  def allJobs
    @jobs_email = params[:email].gsub("\'", "")

    user = User.find(:first , :conditions => {:email => @jobs_email})
    @jobids=[]
    @jobdescs=[]
    @time_left = []
    rogs = Roguenarok.find(:all, :conditions => {:user_id => user.id})
    time_now = Time.new
    time = 60*60*24*7*2 #2 weeks
    rogs.each do |r|
      if r.description.eql?("") || r.description.nil?
        @jobids << r.jobid
        @jobdescs << "";
      else
        @jobids << r.jobid
        @jobdescs << r.description.gsub(/__/," ")
      end
      e = r.created_at.to_s 
      if  e =~ /(\d+)-(\d+)-(\d+)\s*(\d+):(\d+):(\d+)/
        year = $1.to_i
        month = $2.to_i
        day = $3.to_i
        hour = $4.to_i
        minutes = $5.to_i
        seconds = $6.to_i
        create_time = Time.mktime(year,month,day,hour,minutes,seconds)
        sec_left =  time - (time_now.to_i - create_time.to_i)
        minutes = sec_left.to_i/60
        hours = minutes / 60
        days = hours / 24
        days = days+1
        if days > 0
          hours = hours % 24 
          minutes = minutes % 60
          if days > 1
            @time_left << days.to_s+" days"
          else
            @time_left << days.to_s+" day"
          end
        else
          @time_left << "today"
        end
      end  
    end
  end


  def deleteJobs
    jobs_email = params[:email][:email]
    
    if !params[:job].nil?
      params[:job].each do |box|
        no = box[0]
        value = box[1]
        if value.size > 1  #if not marked it should be "0"
          jobid = value
          rog = Roguenarok.find(:first,:conditions => {:jobid => jobid})
          Roguenarok.destroy(rog.id)
          
          # kill all taxa 
          searches = Search.find(:all, :conditions => {:jobid => jobid })
          searches.each do |search | 
            search.destroy
          end
          
          Taxon.delete_all("roguenarok_id = #{jobid}")

          command = "rm -r " + getJobDir(jobid)
          system command
        end
      end
    end
    redirect_to :action => "allJobs" , :email =>  "#{jobs_email}"
  end

  def contact
    @error = ""
    if !(params[:id].nil?)
      @error = "An error occurred, please try again!"
    end
  end

  def sendMessage
    name = params[:contact_name]
    name = name.gsub(/\s/,"__")
    email = params[:contact_email]
    subject = params[:contact_subject]
    subject = subject.gsub(/\s/,"__")
    message = params[:contact_message]
    message = message.gsub(/\n/,"#n#")
    message = message.gsub(/\s/,"__")
    
    if Roguenarok.sendMessage(name,email,subject,message)
      redirect_to :action => "confirmation"
    else
      redirect_to :action => "contact", :id=>1
    end
  end

  def confirmation

  end

  # def citation
    
  # end
  
  def about

  end

  def generateJobID
    id = "#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"	
    searching_for_valid_id = true
    while searching_for_valid_id
      r = Roguenarok.find(:first, :conditions => {:jobid => id})
      if r.nil?
        return id
      end
      id = "#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
    end 
    return id
  end

  def getJobDir(jobid)
    jobs_path = File.join( RAILS_ROOT, "public", "jobs")
    if not APP_CONFIG['pbs_job_folder'].empty?
      jobs_path = APP_CONFIG['pbs_job_folder']
    end
    path = File.join( jobs_path, jobid)
    return path
  end

  def buildJobDir(jobid)
    directory = getJobDir(jobid)
    Dir.mkdir(directory) rescue system("rm -r #{directory}; mkdir #{directory}")

    fh = File.open( File.join( directory, "current.log"), "w")
    fh.write("done!")
    fh.close()
  end

  def destroyJobDir(jobid)
    directory = getJobDir(jobid)
    Dir.rmdir(directory) rescue system("rm -r #{directory};")
  end

  def prepareForTaxaTable(jobid)
    search = Search.find(:first, :conditions => {:jobid => jobid, :name => "dummy"})
    taxa = Taxon.find(:all, :conditions => {:roguenarok_id => jobid,  :search_id => search.id}) 
    
    allTaxa = taxa.select{ |t| t.excluded.eql?("F" )} + taxa.select{ |t| t.excluded.eql?("T" )}
    @allTaxa = allTaxa.map{|t| t.name}
    @allTaxaExcl = allTaxa.select{|t| t.excluded.eql?("T")}.map{ |t| t.name }


    # take notes, if the taxon was checked
    @checkedTaxa = taxa.select{ |t| t.isChecked }.map{|t| t.name}

    otherSearches = Search.find(:all, :conditions => {:jobid => jobid})
    
    @osName = []
    @osId = []
    @allSearchData = []
    @dropsetData = []
    for i in 0..(otherSearches.size-1)
      search = otherSearches[i]
      if ! search.name.eql?("dummy") 
        @osName.push(search.name)
        @osId.push(search.id)
        
        taxa = Taxon.find(:all, :conditions => ["search_id = #{search.id}"])
        
        asHash = {}
        dropsets = {}
        taxa.each do |t|
          if t.excluded.eql?("T")
            asHash[t.name] = "IGN"
          else
            asHash[t.name] = t.score
          end
          
          if  t.dropset != 1
            dropsets[t.name] = t.dropset
          end 

        end

        # add score and dropset data   
        @allSearchData.push(asHash)
        @dropsetData.push(dropsets) 
      end
    end     

    # sort 
    job = Roguenarok.find(:first, :conditions => {:jobid => jobid})
    s = Search.find(:first, :conditions => {:id => job.sortedby})
    if ! s.nil?
      @sortedby = s.id
      tmp = Taxon.find(:all, :conditions => {:search_id => s.id})
      orderedTaxa = tmp.select{|t| t.excluded.eql?("F")} + tmp.select{|t| t.excluded.eql?("T")}
      
      orderedTaxa = orderedTaxa.map{ |t| t.name }
      
      orderedTaxa += (@allTaxa - orderedTaxa)
      @allTaxa = orderedTaxa
    end 
    
    # add color modificator 
    @colMod = []
    for i in 0..(@osName.size-1)
      searchName = @osName[i]

      colsHere = {} 
      minVal= 0.0; maxVal= 1.0
      
      if searchName =~ /tii/ 
        minVal= @allSearchData[i].values.select{|v| ! v.eql?("IGN")}.min
        maxVal= @allSearchData[i].values.select{|v| ! v.eql?("IGN")}.max
        raise "minVal= maxValfor tii scores " if minVal== maxVal
      end

      if searchName =~ /rnr/
        minVal= 0.0
        maxVal= 3.0
      end
      
      if searchName =~ /lsi/
        minVal = -1.0
        maxVal = -0.4
        
        tmp  =   - @allSearchData[i].values.select{|v| ! v.eql?("IGN") }.min
        maxVal = tmp if tmp > maxVal
      end

      @allTaxa.each do |t| 
        if ! @allSearchData[i].nil? && @allSearchData[i].has_key?(t)
          score = @allSearchData[i][t] 

          if ! score.eql?("IGN")
            score = score / @dropsetData[i][t] if @dropsetData[i].has_key?(t)
            
            if searchName =~ /lsi/ 
              score = - score
            end

            col = scoreToColor(score , minVal,maxVal) 
            colsHere[t] = col 
          end
        end
      end
      @colMod.push(colsHere)
    end
  end

  # maps a score to 3 rgb values 
  def scoreToColor(score, minVal, maxVal)
    maxColor = 230.0
    minColor = 10.0
    norm = (((score.to_f - minVal ) / (maxVal - minVal ) )  * (maxColor - minColor)) + minColor    
    norm = [maxColor, norm].min    
    return [minColor, norm, norm]
  end

  def jobIsFinished?(jobid)
    # find the job
    rog = Roguenarok.find(:first, :conditions => {:jobid => jobid})
    if rog == nil
      raise ActionController::RoutingError.new('job not found')
    end
    
    path = getJobDir(jobid)
    
    Dir.glob( File.join( path, "current.log")){|file|
      f = File.open(file,'r')
      fi = f.readlines
      if fi.size > 0
        fi.each do |line|
          if line =~ /^done!\s*$/
            return true
          end
        end
      end
      f.close
    }
    return false
  end
end
