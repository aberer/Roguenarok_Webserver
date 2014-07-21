class ResultFilesParser
  attr_reader :files, :names

  def initialize(path)
    @names = []
    @filenames = []
    getFiles(path)
  end
  
  def getFiles(path)
    Dir.glob(File.join(path,"*")){|file|
      @files << file
    }
    @files.sort!
    @files.each do |file|
      if file =~ /([\w_\-\.\:\;]+)$/
        @names << $1
      else
        @names << File.basename( file)
      end
      @filenames = File.basename( file)
    end
  end

end