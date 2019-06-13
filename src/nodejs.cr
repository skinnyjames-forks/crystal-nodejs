require "io"
require "./nodejs/*"

module Nodejs
  extend self

  NODE_PATH = "#{home_dir}/bin/node"

  def eval(source_code : String, node_path : Array = [] of String) : JSON::Any
    io = IO::Memory.new
    io_error = IO::Memory.new
    status = Process.run(
      NODE_PATH,
      args: {"-e", "#{Values.set_return_js} #{source_code}"},
      env: setup_env(node_path),
      output: io,
      error: io_error
    )

    io.close
    io_error.close

    results = extract_result(io.to_s.chomp)
    display_debug(results[:output])

    unless status.success?
      raise JSSideException.new("Eval: #{io_error.to_s}")
    end

    results[:result]
  end

  def file_run(file_path : String) : JSON::Any
    unless File.exists?(file_path)
      raise CrystalSideException.new("File not found: #{file_path}")
    end
    eval(File.read(file_path))
  end

  def load_jsfile(file_path : String) : String
    path = "#{home_dir}/js/#{file_path}"
    unless File.exists?(path)
      raise CrystalSideException.new("File not found: #{path}")
    end
    File.read(path)
  end

  def replace_params(
    source_code : String,
    replaces : Hash = {String => String | Int32 | Float32}
  ) : String
    replaces.each do |k, v|
      matched = /const[\s]*#{k}[\s]*=[\s]*([\[\]\(\)"'a-z0-9\.\-\_]+)/i.match(source_code)
      unless matched
        raise CrystalSideException.new("No match key:#{k}")
      end
      source_code = source_code.sub(matched.try &.[1], Values.convert_js(v)
      )
    end
    source_code
  end

  def home_dir : String
    "#{ENV["HOME"]}/.crystal-nodejs"
  end

  def version : Void
    status = system("#{NODE_PATH} -v")
    raise CrystalSideException.new("node version") unless status
  end

  def extract_result(res : String) : NamedTuple(result: JSON::Any, output: String)
    matched = /\{"#{Values::RETURN_KEY_NAME}"\:.*\}/.match(res).try &.[0]
    result = JSON.parse("{}")
    output : String
    if matched != nil
      result = JSON.parse(matched.to_s)[Values::RETURN_KEY_NAME]
      output = res.split(matched).join
    else
      output = res
    end
    {result: result, output: output}
  end

  def setup_env(path : Array(String)) : Hash(String, String)
    js_dir = "#{ENV["HOME"]}/.crystal-nodejs/js"
    node_path = {
      "NODE_PATH" => "./:#{js_dir}:#{js_dir}/node_modules:",
    }
    if !path.empty?
      node_path["NODE_PATH"] = "#{node_path["NODE_PATH"]}:#{path.join(":")}"
    end
    node_path
  end

  private def display_debug(output : String) : Void
    unless output.empty?
      puts("#### console.log ####\n#{output}")
    end
  end
end
