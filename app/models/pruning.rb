class Pruning < ActiveRecord::Base
  
attr_accessor :jobid, :threshold, :user_def

  HUMANIZED_ATTRIBUTES = {
    :jobid => "Job ID", :threshold => "Threshold", :user_def => "User defined value"
  }

  def validate 
    # validate threshold user defined value, has to be an integer, nil allowed if not selected
    if threshold.eql?('user')
      if self.user_def.nil? || self.user_def.empty? 
        self.errors.add(:user_def, "cannot be blank!")
      else
        if self.user_def =~ /^(\d+)$/ 
          d = $1.to_i
          if d < 50 || d > 100
            self.errors.add(:user_def, "must be between 50 and 100")
          end
        else
          self.errors.add(:user_def, "must be an integer greater than zero!")
        end
      end
    end
  end

  def execute(link,prune_list)
    path                   = File.join(RAILS_ROOT,"public","jobs",self.jobid)
    bootstrap_treeset_file = File.join(path, "bootstrap_treeset_file")
    best_tree_file         = File.join(path, "best_tree")
    pruned_taxa_file       = File.join(path,"pruned_taxa")
    results_path           = File.join(path,"results")
    current_tree_file      = File.join(path,"current_tree")
    logs_path              = File.join(path,"logs")
    log_out                = File.join(logs_path,"submit.sh.out")
    log_err                = File.join(logs_path,"submit.sh.err")

    current_logfile = File.join(path,"current.log")
    if File.exists?(current_logfile) 
      system "rm #{current_logfile}"
    end

    ### result files
    pruned_bts_file        = File.join(path, "RnR-prune_prunedBootstraps.#{self.jobid}_#{self.id}")
    pruned_best_tree_file  = File.join(path, "RnR-prune_prunedBestTree.#{self.jobid}_#{self.id}")

    raxml_tree_file        = File.join(path, "*ConsensusTree.#{self.jobid}_#{self.id}")
    raxml_best_tree_file   = File.join(path, "RAxML_bipartitionsBranchLabels.#{self.jobid}_#{self.id}")
 
    # build pruned taxa file
    r = Roguenarok.find(:first, :conditions => {:jobid => self.jobid})
    File.open(pruned_taxa_file,'wb'){|file|
      if prune_list.size < 1
        file.write("")
      else
        prune_list.each do |taxon|
          taxon = taxon.sub(/^<del>/, '')
          taxon = taxon.sub(/<\/del>$/,'')
          t = Taxon.find(:first, :conditions => {:name => taxon, :roguenarok_id => r.id})
          t.destroy
          file.write(taxon+"\n")
        end
      end
    }

    # BOOTSTRAP TREESET, DROPSET, NAME, WORKING DIRECTORY
    opts_rnr_prune = {
      "-i" => bootstrap_treeset_file, 
      "-n" => "#{self.jobid}_#{self.id}",
      "-x" => pruned_taxa_file,
      "-w" => path}

    opts_raxml = {
      "-z" => bootstrap_treeset_file, 
      "-n" => "#{self.jobid}_#{self.id}",
      "-m" => "GTRCAT",
      "-w" => path}

    # THRESHOLD
    if self.threshold.eql?("mr")
      opts_raxml["-J"] = "MR"
    elsif self.threshold.eql?("mre")
      otps_raxml["-J"] = "MRE"
    elsif self.threshold.eql?("user")
      opts_raxml["-J"] = "MR"
    elsif self.threshold.eql?("strict")
      opts_raxml["-J"] = "STRICT"
    else # bipartitions
      opts_rnr_prune["-t"] = best_tree_file
      opts_raxml["-f"] = "b"
      opts_raxml["t"] = best_tree_file
    end
    
    job = Roguenarok.find(:first,:conditions => {:jobid => self.jobid})
    user = User.find(:first, :conditions => {:id => job.user_id})
    email = user.email

    # BUILD COMMAND SHELL FILE FOR QSUB
    shell_file = File.join(RAILS_ROOT,"public","jobs",self.jobid,"submit.sh")
    prune = File.join(RAILS_ROOT,"bioprogs","roguenarok","rnr-prune")
    raxml = File.join(RAILS_ROOT,"bioprogs","raxml","raxmlHPC-SSE3")

    command_create_results_folder = "mkdir -p #{results_path}"
    system command_create_results_folder

    command_create_logs_folder = "mkdir -p #{logs_path}"
    system command_create_logs_folder
    
    command_change_directory = "cd #{path}"

    command_rnr_prune = File.join(RAILS_ROOT,"bioprogs","roguenarok","rnr-prune")

    command_update_working_files_after_pruning = "cp #{pruned_bts_file } #{bootstrap_treeset_file}\n cp #{pruned_best_tree_file } #{best_tree_file};"

    command_raxml = File.join(RAILS_ROOT,"bioprogs","raxml","raxmlHPC-SSE3")

    command_update_working_files_after_raxml = "cp #{raxml_tree_file } #{current_tree_file}\n cp #{raxml_best_tree_file } #{current_tree_file};"

    resultfiles_rnr = File.join(path,"RnR*")
    resultfiles_raxml = File.join(path,"RAxML*")
    command_save_result_files="mv #{resultfiles_raxml} #{results_path}\n mv #{resultfiles_rnr} #{results_path}"

    opts_rnr_prune.each_key {|k| command_rnr_prune  = command_rnr_prune+" "+k+" #{opts_rnr_prune[k]} "}
    opts_raxml.each_key {|k| command_raxml  = command_raxml+" "+k+" #{opts_raxml[k]} "}

    command_send_email = ""
    if !(email.nil? || email.empty?)
      command_send_email = File.join(RAILS_ROOT,"bioprogs","ruby","send_email.rb")
      command_send_email = command_send_email + " -e #{email} -l #{link}"
    end

    File.open(shell_file,'wb'){|file| 
      file.write(command_change_directory+"\n")
      file.write(command_rnr_prune+"\n")
      file.write(command_update_working_files_after_pruning+"\n")
      file.write(command_raxml+"\n")
      file.write(command_update_working_files_after_raxml+"\n")
      file.write(command_save_result_files+"\n")
      file.write(command_send_email+"\n")
      file.write("echo done! > #{current_logfile}\n")
    }

    # submit shellfile into batch system 
    qsub_command = "qsub -o #{log_out} -e #{log_err} #{shell_file}"
    system qsub_command
  end
end
