class RoguenarokController < ApplicationController
  
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
   #   #If this user has not used an email address in the past, save it
   #   if @user.email.eql?("")
   #     @user.update_attributes(:email => email)
   #   end

      ### Correction:
      # always update email address
      @user.update_attributes(:email => email)
    else
      @user = User.new({:email => email, :ip => ip, :saved_subs => 0, :all_subs => 0})
      @user.save
      
    end
    #################
    ### save job data & update user submission counter if everything is allright

    @job = Roguenarok.new({:jobid => jobid, :user_id => @user.id, :description => description, :bootstrap_tree_set => bootstrap_treeset_file, :tree => best_known_tree_file, :excluded_taxa => taxa_to_exclude_file})
    buildJobDir(jobid)
    if @job.valid?  && @user.errors.size < 1
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

      # save taxa
      taxa = File.open(@job.taxa_file, 'rb').readlines
      taxa.each do |t|
        taxon = Taxon.new({:roguenarok_id => @job.id, :name => t.chomp!})
        taxon.save
      end
      
      if !taxa_to_exclude_file.nil? && !taxa_to_exclude_file.eql?("")
        ex_taxa = File.open(@job.excluded_taxa, 'rb').readlines
        @job.excludeTaxa(ex_taxa)
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
      render :action => 'submit'
    end
  end

  #######################################################################
  ### WORKFLOW VIEW ####

  def work
    @jobid = params[:jobid]
    job_path = File.join(RAILS_ROOT,"public","jobs",@jobid)
    path     = File.join(job_path,"results")
    ### get result files
    @files = []
    @names = []
    if File.exists?(path) && File.directory?(path)
      r = ResultFilesParser.new(path)
      @names = r.names
      @filenames = r.filenames
    end

    #### CHECK WHICH SUBMISSION HAS TO BE PERFORMED
    
    jobtype = params[:jobtype]
    @job = RogueTaxaAnalysis.new

    ### Taxa Analysis
    if jobtype.eql?("analysis")
      ### Rogue Taxa Analysis
      if params[:taxa_analysis].eql?("Rogue Taxa Analysis")
        tmp = rogueTaxaAnalysis(params)
        if tmp.nil? 
          redirect_to :action => 'wait', :jobid => @jobid
        else
          @job = tmp
        end
      ### LSI Analysis
      elsif params[:taxa_analysis].eql?("LSI")
        tmp = lsiAnalysis(params)
        if tmp.nil? 
          redirect_to :action => 'wait', :jobid => @jobid
        else
          @job = tmp
        end
      ### TII Analysis
      elsif params[:taxa_analysis].eql?("TII")
        tmp = tiiAnalysis(params)
        if tmp.nil? 
          redirect_to :action => 'wait', :jobid => @jobid
        else
          @job = tmp
        end
      end 
    ### Include Taxa
    elsif jobtype.eql?("include")
      includeTaxa(params)
    ### Tree Manipulation
    elsif jobtype.eql?("treeManipulation")
      ### Exclude Taxa
      if params[:tree_manipulation].eql?("Exclude Selected Taxa")
        excludeTaxa(params)
      ### Prune Taxa
      elsif params[:tree_manipulation].eql?("Prune Selected Taxa")
        tmp = prune(params)
        if tmp.nil? 
          redirect_to :action => 'wait', :jobid => @jobid
        else
          @job = tmp
        end
      end
    end

    
    #### INITIALIZE VARIABLES FOR THE FORM. KEEP OLD SELECTIONS WHEN AN ERROR OCCURRED.

    threshold = params[:threshold]
    @strict = false
    @mr = false
    @mre = false
    @user_def = false
    @user_def_value = nil
    @bipartitions = false
    @best_tree_available = !File.exists?(File.join(RAILS_ROOT, "public", "jobs", @jobid, "best_tree"))
  
    ### Initialize Job Description
    job = Roguenarok.find(:first, :conditions => ["jobid = #{@jobid}"])
    @description = job.description
    if @description.nil? || @description.empty?
      @description = "none"
    end

    ### Initialize Threshold Selection
    if threshold.eql?('mr')
      @mr = true
    elsif threshold.eql?('mre')
      @mre = true
    elsif threshold.eql?('user') 
      @user_def = true
      @user_def_value = params[:threshold_user_defined]
    elsif threshold.eql?('bipartitions')
      @bipartitions = true
    else # set strict as default
      @strict = true
    end

    ### Initialize Optimization Selection
    optimize = params[:optimize]
    @support = false
    @numb_bipart = false
    if optimize.eql?("number_of_bipartitions")
      @numb_bipart = true
    else # support is default
      @support = true
    end
      

    ### Initialize dropset value
    @dropset = params[:dropset]
    if @dropset.nil? || @dropset.empty?
      @dropset = 1
    end

    ### Initialize excluded taxa 
    @ex_taxa = []
    @ex_cols = 0
    @ex_rows = 0
    ex_taxa = Taxon.find(:all, :conditions => { :roguenarok_id => "#{job.id}", :excluded => "T"})
    col = 0
    row = 0
    
    ### Initialize current tree
    @current_tree = nil
    if File.exists?(File.join(job_path,"current_tree"))
      @current_tree = File.open(File.join(job_path,"current_tree"),'r').readlines.join
    end

    # Generate a dynamically growing table with a maximum of 5 columns
    for i in 0..ex_taxa.size-1
      if @ex_taxa[col].nil?
        @ex_taxa[col] = []
      end
      @ex_taxa[col].push(ex_taxa[i])
      row = row+1
      if @ex_taxa[col].size > 10
      col = col+1
        if @ex_taxa[col].nil?
         row = 0
        else
          row = @ex_taxa[col].size
        end
      end
     if col > 4
        col = 0
        row = @ex_taxa[0].size
      end
        
    end
    if @ex_taxa.size > 0
      @ex_cols = @ex_taxa.size
      @ex_rows = @ex_taxa[0].size
    else
      @ex_cols = 0
      @ex_rows = 0
    end
    
    ### Initialize Taxa Analysis Options
    @taxa_analysis_options = "";
    roguenarok = "Rogue Taxa Analysis"
    lsi        = "LSI"
    tii        = "TII"

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
    exclude_taxa = "Exclude Selected Taxa"
    prune_taxa = "Prune Selected Taxa"
    exclude_taxa_option =  "<option>#{exclude_taxa}</option>"
    prune_taxa_option = "<option>#{prune_taxa}</option>"
    if params[:tree_manipulation].eql?(exclude_taxa)
      exclude_taxa_option = "<option selected=\"selected\">#{exclude_taxa}</option>"
    elsif params[:tree_manipulation].eql?(prune_taxa)
      prune_taxa_option = "<option selected=\"selected\">#{prune_taxa}</option>"
    end
    @tree_manipulation_options = exclude_taxa_option+prune_taxa_option
    
    ### Initialize Taxa Listing 
    taxa = Taxon.find(:all, :conditions => ["roguenarok_id = #{job.id}"])
    @taxa = taxaToTable(taxa)
  end
  
  def rogueTaxaAnalysis(params)
    ### Collect parameters for Rogue Taxa Analysis and try to save them
    jobid = params[:jobid]
    threshold = params[:threshold]
    user_def = 1
    if threshold.eql?("user")
      user_def = params[:threshold_user_defined]
    end
    optimize = params[:support]
    dropset = params[:dropset]
    job = RogueTaxaAnalysis.new({:jobid => jobid, :threshold => threshold, :user_def => user_def, :optimize => optimize, :dropset => dropset})
    
    ### If the input parameters have passed the validation, execute and return true
    if job.valid?
      job.save
      link = url_for :controller => 'roguenarork', :action => 'work', :id => jobid
      job.execute(link)
      return nil
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
    job.includeTaxa(list)
  end

  def excludeTaxa(params)
    job = Roguenarok.find(:first, :conditions => {:jobid => params[:jobid]})
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
    job.excludeTaxa(list)
  end

  def prune(params)
     ### Collect parameters for pruning and try to save them
    jobid = params[:jobid]
    threshold = params[:threshold_prune]
    user_def = 1
    if threshold.eql?("user")
      user_def = params[:threshold_prune_user_defined]
    end
    job = Pruning.new({:jobid => jobid, :threshold => threshold, :user_def => user_def})
    
    ### If the input parameters have passed the validation, execute and return true
    if job.valid?
      job.save
      link = url_for :controller => 'roguenarork', :action => 'work', :id => jobid

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

      job.execute(link,list)
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
      link = url_for :controller => 'roguenarork', :action => 'work', :id => jobid
      job.execute(link)
      return nil
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
      link = url_for :controller => 'roguenarork', :action => 'work', :id => jobid
      job.execute(link)
      return nil
    else
      job.errors.each do |field,error|
        puts field
        puts error
      end
      return job
    end
  end

  def wait
    @jobid = params[:jobid]
      
    if !(jobIsFinished?(@jobid))
      render :action => 'wait' ,:jobid => @jobid
    else
      redirect_to :action => 'work', :jobid => @jobid
    end
  end

  def look
    @error_id = ""
    @error_email = ""
    if !(params[:jobid].nil?)
      @error_id = "The job  with the id \'#{params[:jobid]}\' does not exists or is not finished yet"
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
        redirect_to :action => "work" , :jobid => jobid
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
    @jobs_email = params[:email]
    users = User.find(:all , :conditions => {:email => @jobs_email})
    @jobids=[]
    @jobdescs=[]
    @time_left = []
    users.each do |u|  
      rog =  Roguenarok.find(:all, :conditions => {:user_id => u.id})
      time_now = Time.new
      time = 60*60*24*7*2 #2 weeks
      rog.each do |r|
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
  end


  def deleteJobs
    jobs_email = params[:email][:email]
    if !params[:jobs].nil?
      params[:jobs].each do |box|
        no = box[0]
        value = box[1]
        if value.size > 1  #if not marked it should be "0"
          jobid = value
          rog = Roguenarok.find(:first,:conditions => {:jobid => jobid})
          Roguenarok.destroy(rax.id)
          taxa = Taxon.find(:all,:conditions => {:roguenarok_id => rog.id})
          taxa.each do |taxon|
            taxon.destroy
          end
          command = "rm -r " + File.join( RAILS_ROOT, "public", "jobs", jobid)
          system command
        end
      end
    end
    redirect_to :action => "allJobs" , :email =>  "#{jobs_email}"
  end

  def contact
    @error = ""
    if !(params[:id].nil?)
      @error = "An error occurres, please try again!"
    end
  end

  def sendMessage
    name = params[:contact_name]
    name = name.gsub(/\s/,"__")
    email = params[:contact_email]
    subject = params[:contact_subject]
    subject = subject.gsub(/\s/,"__")
    subject = subject.gsub(/\"/,"\\\"")
    subject = subject.gsub(/\'/,"\\\\\'")
    message = params[:contact_message]
    message = message.gsub(/\n/,"#n#")
    message = message.gsub(/\s/,"__")
    message = message.gsub(/\"/,"\\\"")
    message = message.gsub(/\'/,"\\\\\'")
    if Roguenarok.sendMessage(name,email,subject,message)
      redirect_to :action => "confirmation"
    else
      redirect_to :action => "contact", :id=>1
    end
  end

  def confirmation

  end

  def about

  end
  
  def download 
    jobs_path = Pathname.new( File.join( RAILS_ROOT, "public", "jobs"))
    jobid    = File.basename( params[:jobid])
    filename = File.basename( params[:filename])
    file = jobs_path.join( jobid, "results", filename).cleanpath
    if( file.to_s =~ /#{jobs_path.to_s}/)
      send_file file
    else
      raise ActionController::RoutingError.new('Not Found')
    end
  end

  def generateJobID
    id = "#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"	
    searching_for_valid_id = true
    while searching_for_valid_id
      r = Roguenarok.find(:first, :conditions => {:jobid => id})
      if r.nil?
        return id
      end
      id  = "#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
    end 
    return id
  end

  def buildJobDir(jobid)
    directory = File.join( RAILS_ROOT, "public", "jobs", jobid)
    Dir.mkdir(directory) rescue system("rm -r #{directory}; mkdir #{directory}")
  end

  def destroyJobDir(jobid)
    directory = File.join( RAILS_ROOT, "public", "jobs", jobid)
    Dir.rmdir(directory) rescue system("rm -r #{directory};")
  end

  def taxaToTable(taxa)

    # sort by names
    names = Hash.new
    taxa.each do |t|
      if t.excluded.eql?("T")
        if names["<del>#{t.name}</del>"].nil?
          names["<del>#{t.name}</del>"] = []
          names["<del>#{t.name}</del>"] << t
        else
          names["<del>#{t.name}</del>"] << t
        end
      else
        if names[t.name].nil?
          names[t.name] = []
          names[t.name] << t
        else
          names[t.name] << t
        end
      end
    end
    
    score_types = Hash.new
    names.each_key do |k|
      scores = Hash.new
      for i in 0..names[k].size-1
        taxon = names[k][i]

        # determine score name extensions
        dropset = ""
        bipart = ""
        support = ""
        user_def = ""
        if !taxon.dropset.nil?
          dropset = "ds#{taxon.dropset}"
        end
        if !taxon.n_bipart.nil?
          bipart = "bipart"
        end
        if !taxon.support.nil?
          support = "sup"
        end
        if !taxon.userdef.nil?
          user_def = "userDef#{taxon.user_def}"
        end
        ### Save scores
        if !taxon.strict.nil?
          scores["strict_"+sup+bipart+"_"+dropset] = taxon.strict  # only sup or bipart can be selected, so one of it is ""
          score_types["strict_"+sup+bipart+"_"+dropset] = ""
        end
        if !taxon.mr.nil?
          scores["mr_"+sup+bipart+"_"+dropset] = taxon.mr
          score_types["mr_"+sup+bipart+"_"+dropset] = ""
        end
        if !taxon.mre.nil?
          scores["mre_"+sup+bipart+"_"+dropset] = taxon.mre
          score_types["mre_"+sup+bipart+"_"+dropset] = ""
        end
        if !taxon.userdef.nil?
          scores[user_def+"_"+sup+bipart+"_"+dropset] = taxon.userdef
          score_types[user_def+"_"+sup+bipart+"_"+dropset] = ""
        end
        if !taxon.bipart.nil?
          scores["bipart_"+sup+bipart+"_"+dropset] = taxon.bipart
          score_types["bipart_"+sup+bipart+"_"+dropset] = ""
        end
        if !scores["lsi_dif"].nil?
          scores["lsi_dif"] = taxon.lsi_dif
          score_types["lsi_dif"] = ""
        end
        if !scores["lsi_ent"].nil?
          scores["lsi_ent"] = taxon.lsi_ent
          score_types["lsi_ent"] = ""
        end
        if !scores["lsi_max"].nil?
          scores["lsi_max"] = taxon.lsi_max
          score_types["lsi_max"] = ""
        end
        if !scores["tii"].nil?
          scores["tii"] = taxon.tii
          score_types["tii"] = ""
        end
      end
      names[k] = scores
    end
    ### add missing cells
    headers = Array.new
    names.each_key do |name|
      score_types.each_key do |tp|
        headers << tp
        if names[name][tp].nil?
          names[name][tp] = "-"
        end
      end
    end
   
    ### sort table columns alphabetically
    table = Hash.new

    headers.sort!
    headers = ["Name"].concat(headers)
    headers.each do |h|
      names.each_key do |name|
        if table[name].nil?
          table[name] = []
          table[name] << name
          if !h.eql?("Name")
            table[name] << names[name][h]
          end
        elsif !h.eql?("Name")
          table[name] << names[name][h]
        end
      end
    end
    table["header"] = headers
    return table  #[taxa_name][score_name][score]
  end

  def jobIsFinished?(jobid)
    rog = Roguenarok.find(:first, :conditions => {:jobid => jobid}) 
    path = File.join(RAILS_ROOT,"public","jobs",jobid)
    finished = false
    Dir.glob(File.join(path,"current.log")){|file|
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
    return finished       
  end

end
