class LsiAnalysis < ActiveRecord::Base
  attr_accessor :jobid, :dif, :ent, :max

  HUMANIZED_ATTRIBUTES = {
    :jobid => "Job ID", :dif => "DIF", :ent => "ENT", :max => "Max"
  }

  def validate

    # validate dropset, not nil, has to be an integer
    if self.dif.nil? && self.ent.nil? && self.max.nil? 
      self.errors.add(:dif, "At least one checkbox has to be selected!")
    end
  end

  def execute(link)
    path                   = File.join(RAILS_ROOT,"public","jobs",self.jobid)
    bootstrap_treeset_file = File.join(path, "bootstrap_treeset_file")
    best_tree_file         = File.join(path, "best_tree")
    excluded_taxa_file     = File.join(path, "excluded_taxa")
    results_path           = File.join(path, "results")
    logs_path              = File.join(path, "logs")
    log_out                = File.join(logs_path, "submit.sh.out")
    log_err                = File.join(logs_path, "submit.sh.err")

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

    shell_file = File.join( RAILS_ROOT, "public", "jobs", self.jobid, "submit.sh")

    command_create_results_folder = "mkdir -p #{results_path}"
    system command_create_results_folder

    command_create_logs_folder = "mkdir -p #{logs_path}"
    system command_create_logs_folder

    command_change_directory = "cd #{path}"

    command_rnr_lsi = File.join(RAILS_ROOT,"bioprogs","roguenarok","rnr-lsi")
    opts.each_key {|k| command_rnr_lsi  = command_rnr_lsi + " " + k + " #{opts[k]} "}

    resultfiles = File.join(path,"RnR*")
    command_save_result_files="mv #{resultfiles} #{results_path}"

    File.open(shell_file,'wb', 0664){|file| 
      file.write("#PBS -S /bin/bash\n")
      file.write("#PBS -o #{log_out}\n")
      file.write("#PBS -e #{log_err}\n")
      file.write("#PBS -W umask=022\n")
      file.write(command_change_directory+"\n")
      file.write(command_rnr_lsi+"\n")
      file.write(command_save_result_files+"\n")
      file.write("echo done! > #{current_logfile}\n")
    }

    # submit shellfile into batch system 
    qsub_command = "qsub #{shell_file}"
    system qsub_command
  end

  def getName
    return "lsi_" +  self.id.to_s
  end
  
  def getFile
    file = File.join(RAILS_ROOT, "public", "jobs", self.jobid, "results", "RnR-lsi_leafStabilityIndices.#{self.jobid}_#{self.id}")
    return file
  end

end