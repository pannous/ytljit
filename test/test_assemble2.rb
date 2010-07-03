require 'test/unit'
require 'lib/ytljit/ytljit.rb'

include YTLJit

class Integer
  def to_as
    "$0X#{self.to_s(16)}"
  end
end

class InstructionTests < Test::Unit::TestCase
  include X86

  def setup
    @cs = CodeSpace.new
    @asm = Assembler.new(@cs, GeneratorExtend)
    @asout = ""
    @regs = [EAX, ECX, EDX, EBX, EBP, EDI, ESI, ESP]
#    @lits = [OpImmidiate32.new(0x0), OpImmidiate32.new(0x92),
#             OpImmidiate32.new(0x8212), OpImmidiate32.new(0x12345678)]
    @lits = [0, 0x92, 0x8212, 0x12345678, 0xffffffff]
    @indirects = []
    [EBP, EDI, ESI, ESP].each do |reg|
      [0, 12, 255, 8192, 65535].each do |offset|
        @indirects.push OpIndirect.new(reg, offset)
      end
    end
  end

  def asm_ytljit(nm, dst, src)
    @asm.with_retry do
      @asm.send(nm, dst, src)
    end
  end

  def disasm_ytljit(cs)
    tmpfp = Tempfile.open("ytljitcode")
    tmpfp.write cs.code
    tmpfp.close(false)
    # quick dirty hack to work on Cygwin & Mac OS X/Core2Duo
    # TODO: bdf and instruction set architecture should be automatically selected
    case $ruby_platform
    when /x86_64-darwin/
      objcopy_cmd = "gobjcopy -I binary -O mach-o-i386 -B i386 --adjust-vma=#{cs.base_address} #{tmpfp.path}"
      objdump_cmd = "gobjdump -M x86-64 -D #{tmpfp.path}"
      
    when /x86_64/
      objcopy_cmd = "objcopy -I binary -O elf64-x86-64 -B i386 --adjust-vma=#{cs.base_address} #{tmpfp.path}"
      objdump_cmd = "objdump -M x86-64 -D #{tmpfp.path}"
      
    when /i.86/
      objcopy_cmd = "objcopy -I binary -O elf32-i386 -B i386 --adjust-vma=#{cs.base_address} #{tmpfp.path}"
      objdump_cmd = "objdump -M i386 -D #{tmpfp.path}"
    end
    system(objcopy_cmd)
    res = []
    File.popen(objdump_cmd, "r") {|fp|
      fp.readlines.each do |lin|
        if /([0-9a-f]*):(\t[0-9a-f ]+? *\t.*)/ =~ lin then
          res.push lin
        end
      end
    }

    res
  end

  def asm_gas(nm, dst, src)
    if dst then
      if src then
        @asout += "\t#{nm}\t#{src.to_as}, #{dst.to_as}\n"
      else
        @asout += "\t#{nm}\t#{dst.to_as}\n"
      end
    else
      if src then
        @asout += "\t#{nm}\t#{src.to_as}\n"
      else
        @asout += "\t#{nm}\n"
      end
    end
  end

  def disasm_gas(cs)
    tmpfp = Tempfile.open("gascode")
    tmpfp.write @asout
    tmpfp.close(false)
    system("as #{tmpfp.path}")

    case $ruby_platform
    when /x86_64-darwin/
      objdump_cmd = "gobjdump -M x86-64 -D --adjust-vma=#{cs.base_address} a.out"
      
    when /x86_64/
      objdump_cmd = "objdump -M x86-64 -D --adjust-vma=#{cs.base_address} a.out"
      
    when /i.86/
      objdump_cmd = "objdump -M i386 -D --adjust-vma=#{cs.base_address} a.out"
    end

    res = []
    File.popen(objdump_cmd, "r") {|fp|
      fp.readlines.each do |lin|
        if /([0-9a-f]*):(\t[0-9a-f ]+? *\t.*)/ =~ lin then
          res.push lin
        end
      end
    }

    res
  end

  def test_asm
    [:mov, :add, :or, :adc, :sbb, :and, :sub, :xor, :cmp].each do |mnm|
      @regs.each do |reg|
        @lits.each do |src|
          asm_ytljit(mnm, reg, src)
          asm_gas(mnm, reg, src)
        end
      end
      @indirects.each do |dst|
        #      asm_ytljit(mnm, dst, @lits[0])
        #      asm_gas(mnm, dst, @lits[0])
        @regs.each do |src|
          asm_ytljit(mnm, dst, src)
          asm_gas(mnm, dst, src)
        end
      end
      
      ytlres = disasm_ytljit(@cs)
      gasres = disasm_gas(@cs)
      ytlres.each_with_index do |lin, i|
        assert_equal(gasres[i], lin)
      end
      @cs.reset
      @asout = ""
    end
  end
end