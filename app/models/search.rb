class Search < ActiveRecord::Base
  attr_accessor :mode
  
  def parseResult    
    if name.starts_with?("rnr")
      parseRnrResult
    end

    if name.starts_with?("lsi")
      parseLsiResult
    end

    if name.starts_with?("tii")
      parseTiiResult
    end
  end

  def parseRnrResult
    fh = File.open(filename)
    
    # first two lines are not interesting
    fh.gets
    fh.gets

    while line = fh.gets
      tok = line.split("\t")            
      specNames = tok[2].split(",")
      score = tok[3]
      pos = tok[0]
      
      specNames.each do |name|
        if score.eql?("NA")
          t = Taxon.new({:search_id => self.id, :roguenarok_id => jobid, :name => name, :pos => pos, :excluded => "T"})
          t.save
        else
          score = tok[3].to_f
          t = Taxon.new({:search_id => self.id, :roguenarok_id => jobid, :name => name, :pos => pos, :score => score, :dropset => specNames.length})
          t.save
        end
      end 
    end 

    fh.close
  end

  def parseLsiResult
    fh = File.open(filename)
    fh.gets

    taxaList = []

    while line = fh.gets
      tok = line.split("\t")
      name = tok[0]

      score = tok[1] if self.mode == :dif
      score  = tok[2] if self.mode == :ent
      score  = tok[2] if self.mode == :max 
      
      if score =~ /NA/
        taxaList.push(Taxon.new({:search_id => self.id, :roguenarok_id => jobid, :name => name, :excluded => "T", :score => -1}))
      else
        score = score.to_f
        taxaList.push(Taxon.new({:search_id => self.id, :roguenarok_id => jobid, :name => name, :score => score}))
      end
    end
    
    taxaList.sort! { |x,y|  x.score <=> y.score }
    
    cnt = 1
    taxaList.each do |t|
      t.pos = cnt
      cnt += 1 
      t.save
    end
    
    fh.close    
  end

  def parseTiiResult
    fh = File.open(filename)
    
    taxaList = []
    while line = fh.gets
      tok = line.split("\t")
      name = tok[0]
      score = tok[1] 

      if score =~ /NA/
        taxaList.push(Taxon.new({:search_id => self.id, :roguenarok_id => jobid, :name => name, :excluded => "T", :score => -1}))
      else
        score = score.to_f
        taxaList.push(Taxon.new({:search_id => self.id, :roguenarok_id => jobid, :name => name, :score => score}))
      end      
    end
    
    taxaList.sort! { |x,y|  y.score <=> x.score  }
    
    cnt = 1
    taxaList.each do |t|
      t.pos = cnt
      cnt += 1
      t.save
    end
    
    fh.close()
  end
end

