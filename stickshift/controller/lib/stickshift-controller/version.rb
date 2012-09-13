module StickShift
  VERSION = File.open("#{File.dirname(__FILE__)}/../../rubygem-stickshift-controller.spec"
                        ).readlines.delete_if{ |x| !x.match(/Version:/)
                        }.first.split(':')[1].strip
end
