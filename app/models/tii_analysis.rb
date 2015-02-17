class TiiAnalysis < ActiveRecord::Base
   attr_accessor :jobid

  HUMANIZED_ATTRIBUTES = {
    :jobid => "Job ID"
  }

  def getJobDir
    jobs_path = File.join( RAILS_ROOT, "public", "jobs")
    if not APP_CONFIG['pbs_job_folder'].empty?
      jobs_path = APP_CONFIG['pbs_job_folder']
    end
    path = File.join( jobs_path, self.jobid)
    return path
  end

  def getBioprogsDir
    dir = File.join(RAILS_ROOT,"bioprogs")
    if not APP_CONFIG['pbs_bioprogs_folder'].empty?
      dir = APP_CONFIG['pbs_bioprogs_folder']
    end
    return dir
  end

  def execute(link)
    path                   = getJobDir()
    bootstrap_treeset_file = File.join( path, "bootstrap_treeset_file")
    best_tree_file         = File.join( path, "best_tree")
    excluded_taxa_file     = File.join( path, "excluded_taxa")
    results_path           = File.join( path, "results")
    logs_path              = File.join( path, "logs")
    log_out                = File.join( logs_path, "submit.sh.out")
    log_err                = File.join( logs_path, "submit.sh.err")
    
    if not APP_CONFIG['pbs_server'].empty?
      log_out = "#{APP_CONFIG['pbs_server']}:#{log_out}"
      log_err = "#{APP_CONFIG['pbs_server']}:#{log_err}"
    end

    current_logfile = File.join(path,"current.log")
    if File.exists?(current_logfile) 
      system "rm #{current_logfile}"
    end
    
    # BOOTSTRAP TREESET, DROPSET, NAME, WORKING DIRECTORY
    opts = {
      "-i" => bootstrap_treeset_file, 
      "-n" => "#{self.jobid}_#{self.id}",
      "-w" => path}
    
    # EXCLUDED TAXA
    if File.exists?(excluded_taxa_file)
      opts["-x"] = excluded_taxa_file
    end
    
    job = Roguenarok.find(:first,:conditions => {:jobid => self.jobid})
    user = User.find(:first, :conditions => {:id => job.user_id})
    email = user.email

    # BUILD SHELL FILE FOR QSUB

    shell_file =File.join(getJobDir(),"submit.sh")

    command_create_results_folder = "mkdir -p #{results_path}"
    system command_create_results_folder

    command_create_logs_folder = "mkdir -p #{logs_path}"
    system command_create_logs_folder

    command_change_directory = "cd #{path}"

    command_rnr_tii = File.join(getBioprogsDir(),"roguenarok","rnr-tii")
    opts.each_key {|k| command_rnr_tii  = command_rnr_tii+" "+k+" #{opts[k]} "}
    
    resultfiles = File.join(path,"RnR*")
    command_save_result_files="mv #{resultfiles} #{results_path}"

    File.open(shell_file,'wb', 0664){|file| 
      file.write("#PBS -S /bin/bash\n")
      file.write("#PBS -o #{log_out}\n")
      file.write("#PBS -e #{log_err}\n")
      file.write("#PBS -W umask=022\n")
      file.write(command_change_directory+"\n")
      file.write(command_rnr_tii+"\n")
      file.write(command_save_result_files+"\n")
      file.write("echo done! > #{current_logfile}\n")
    }

    # submit shellfile into batch system 
    qsub_command = "qsub #{shell_file}"
    system qsub_command
  end

  def getName
    result = "tii_" + self.id.to_s
    return result
  end

  def getFile
    file = File.join( getJobDir(), "results", "RnR-tii_taxonomicInstabilityIndex.#{self.jobid}_#{self.id}")
    return file
  end

end