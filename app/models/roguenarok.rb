class Roguenarok < ActiveRecord::Base
  has_many :search
  belongs_to :user
  
  attr_accessor :bootstrap_tree_set, :tree, :excluded_taxa, :taxa_file
  ### Standard validator functions
  validates_presence_of :bootstrap_tree_set, :message =>"cannot be blank!"


  def assertSameTaxonSet(bestTreeFile, taxaFile)
    taxa = File.open(taxaFile, "r").readlines.map{|v| v.chomp }
    
    tree =  File.open(bestTreeFile, "r").readline
    taxaInTree = tree.scan(/([A-Za-z][^\(\);:,]+)/).map{ |v| v[0].chomp }

    result = taxaInTree.length == taxa.length    
    taxa.map{|v| taxaInTree.include?(v)}.reduce(result){ |value,result| result &= value}
    
    return result 
  end


  ### custom validator function that checks file formats of the uploaded files
  def validate
    jobdir = getJobDir()

    #validate bootstrap treeset file
    if ! ( self.bootstrap_tree_set.nil? || self.bootstrap_tree_set.eql?(""))
      b = TreeFileParser.new(self.bootstrap_tree_set)
      errors.add(:bootstrap_tree_set, b.error) if !b.valid_format
      if b.valid_format
        bts_path = File.join(jobdir,"bootstrap_treeset_file")
        saveOnDisk(b.data, bts_path)
        self.bootstrap_tree_set = bts_path
        # build taxa file and check if everything worked out
        self.taxa_file = b.buildTaxaFile(self.jobid, bts_path)
      else 
        self.bootstrap_tree_set = ""
      end
      errors.add(:bootstrap_tree_set, b.error) if !b.valid_format 
      
      if ! self.bootstrap_tree_set.eql?("") && File.open(self.bootstrap_tree_set, "r").readlines.length < 2
        errors.add(:bootstrap_tree_set, "Your bootstrap tree file only contains a single tree.")
      end 
    end

    # validate tree file
    if !self.tree.eql?("") 
      t = TreeFileParser.new(self.tree)
      errors.add(:tree, t.error) if !t.valid_format
      if t.valid_format
        tree_path = File.join(jobdir,"best_tree")
        saveOnDisk(t.data, tree_path)
        self.tree = tree_path
      else
        self.tree =""
      end
      
      if  ! self.tree.eql?("") &&  File.open(self.tree).readlines.length > 1 
        errors.add(:best_known_tree_file , "cannot contain more than one tree (in one line; newick format)")
      end

# TODO do not know what's wrong here 
#       if  ! self.tree.eql?("") && ! self.taxa_file.nil? && ! assertSameTaxonSet(self.tree, self.taxa_file)
#         errors.add(:best_known_tree_file, "did not contain the same set of taxa as the bootstrap tree file.")
#       end
    end

    # validate excluded taxa file
    if !self.excluded_taxa.nil? && !self.excluded_taxa.eql?("")
      e = ExcludedTaxaFileParser.new( self.excluded_taxa, self.taxa_file)
      errors.add(:excluded_taxa, e.error) if !e.valid_format
      if e.valid_format
        excluded_taxa_path = jobdir + "excluded_taxa"
        saveOnDisk(e.data, excluded_taxa_path)
        self.excluded_taxa = excluded_taxa_path
      end
    end
  end

  def getJobDir
    jobs_path = File.join( RAILS_ROOT, "public", "jobs")
    if not APP_CONFIG['pbs_job_folder'].empty?
      jobs_path = APP_CONFIG['pbs_job_folder']
    end
    path = File.join( jobs_path, self.jobid)
    return path
  end

  def saveOnDisk(data,path)
    File.open(path,'wb'){|f| f.write(data.join)}
  end

  def excludeTaxa(jobid, list)
    ds = Search.find(:first, :conditions => {:jobid => jobid, :name => "dummy"} )

    self.excluded_taxa = File.join( getJobDir(), "excluded_taxa")
    list.each do |name|
      t = Taxon.find(:first, :conditions => {:roguenarok_id => jobid, :search_id => ds.id, :name => name.chomp} )
      t.update_attributes(:excluded => 'T')
    end

    # update excluded taxa file
    taxaList = Taxon.find(:all, :conditions => {:roguenarok_id => jobid, :search_id => ds.id, :excluded => 'T'} )
    f = File.open(self.excluded_taxa, 'wb')
    taxaList.each do |t|
      f.write(t.name + "\n")
    end
    f.close
  end

  def includeTaxa(jobid, list)
    ds = Search.find(:first, :conditions => {:jobid => jobid, :name => "dummy"} )
    
    self.excluded_taxa = File.join( getJobDir(),"excluded_taxa")
    list.each do |name|
      t = Taxon.find(:first, :conditions => {:roguenarok_id => jobid, :search_id => ds.id , :name => name.chomp} )
      t.update_attributes(:excluded => 'F')
    end

    # update excluded taxa file
    taxa = Taxon.find(:all, :conditions => {:roguenarok_id => jobid, :search_id => ds.id, :excluded => 'T'} )
    f = File.open(self.excluded_taxa, 'wb')    
    taxa.each do |taxon|
      f.write(taxon.name+"\n")
    end
    f.close
  end
  
  def Roguenarok.sendMessage(name,email,subject,message)  
    command = File.join(RAILS_ROOT,"bioprogs","ruby","send_message.rb")
    if !(name.nil? || name.eql?(""))
      command = command+" -n #{name} "
    end
    if email=~/^\S+@\S+/
      command = command+" -e #{email} "
    end
    if !(subject.nil? || subject.eql?(""))
      command = command+" -s #{subject} "
    end
    command = command+" -m #{message} "
    
    email = [name , email, subject, message].join("<>")
    # logger.warn "\n\n" + email  + "\n\n"
    
    system command # if more traffic on the server is occuring (at this moment, the server can handle three parallel requests)  this should be submitted to the batch system
    return true
  end

 end