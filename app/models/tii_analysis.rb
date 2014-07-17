class TiiAnalysis < ActiveRecord::Base
   attr_accessor :jobid

  HUMANIZED_ATTRIBUTES = {
    :jobid => "Job ID"
  }

  def execute(link)
    path                   = File.join(RAILS_ROOT,"public","jobs",self.jobid)
    bootstrap_treeset_file = File.join(path, "bootstrap_treeset_file")
    best_tree_file         = File.join(path, "best_tree")
    excluded_taxa_file     = File.join(path,"excluded_taxa")
    results_path           = File.join(path,"results")
    logs_path              = File.join(path,"logs")
    
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

    shell_file =File.join(RAILS_ROOT,"public","jobs",self.jobid,"submit.sh")

    command_create_results_folder = "mkdir #{results_path}"
    if File.exists?(results_path) && File.directory?(results_path)
      command_create_results_folder = ""
    end

    command_create_logs_folder = "mkdir #{logs_path}"
    if File.exists?(logs_path) && File.directory?(logs_path)
      command_create_logs_folder = ""
    end

    command_rnr_tii = File.join(RAILS_ROOT,"lib","rnr-tii")
    opts.each_key {|k| command_rnr_tii  = command_rnr_tii+" "+k+" #{opts[k]} "}
    
    resultfiles = File.join(path,"RnR*")
    command_save_result_files="mv #{resultfiles} #{results_path}"

    logfiles = File.join(path,"submit.sh.*")
    current_logfile = File.join(path,"current.log")
    command_save_log_files = "cp #{logfiles} #{current_logfile};mv #{logfiles} #{logs_path}"

    File.open(shell_file,'wb'){|file| 
      file.write(command_create_results_folder+"\n")
      file.write(command_create_logs_folder+"\n")
      file.write(command_rnr_tii+"\n")
      file.write(command_save_result_files+"\n")
      file.write("echo done!\n")
      file.write(command_save_log_files+"\n")
    }

    # submit shellfile into batch system 
    system "qsub -o #{path} -j y #{shell_file} "
  end


  def getName
    result = "tii_" + self.id.to_s
    return result
  end

  def getFile
    file = "#{RAILS_ROOT}/public/jobs/#{self.jobid}/results/RnR-tii_taxonomicInstabilityIndex.#{self.jobid}_#{self.id}"
    return file
  end

end
