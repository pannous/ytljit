# test program
require 'ytljit'
require 'pp'

include YTLJit
is = RubyVM::InstructionSequence.compile(
#       "class Foo; def test(x);a = 0; x= 1;lambda {a = a + 1};p a;end;end","", "", 0,
#        "b = 0;def test(x);a = 0;lambda {a = a + 1};p a;end;test(0)","", "", 0,
#         "def test(x);a = x + 1;p a; p x;end;test(3)","", "", 0,
#        "def test(x);if x then a = 1 else a = 3 end;p a end;test(3)","", "", 0,
#        "def test(x);if x == 3 then a = 1 else a = 3 end;p a end;test(3)","", "", 0,
        "def fib(x);if x < 2 then 1 else fib(x + -1) + fib(x + -2) end;end;p fib(35)","", "", 0,
#        "def ffib(x);if x < 2 then 1.0 else ffib(x + -1) + ffib(x + -2) end;end;p ffib(5)","", "", 0,
#        "def foo; [1, 2, 3][0] + [1, 2, 3][1]  end; p foo", "", "", 0, 
#        "def foo(x); if x then x = 1 else x = 2 end; x; end; p foo(1)", "", "", 0, 
#        "def foo(x); if x then x = 2.0 else x = 1 end; x; end; p foo(1)", "", "", 0, 
#         "def foo(x); yield(x); end; p foo(1) {|a| a + 1}", "", "", 0, 
#        "1.1","", "", 0,
              {  :peephole_optimization    => true,
                 :inline_const_cache       => false,
                 :specialized_instruction  => false,}
     ).to_a
iseq = VMLib::InstSeqTree.new(nil, is)
pp iseq

tr = VM::YARVTranslatorSimple.new([iseq])
tnode = tr.translate
context = VM::CollectInfoContext.new(tnode)
tnode.collect_info(context)
File.open("out.marshal", "w") do |fp|
  fp.print Marshal.dump(tnode)
end
context = VM::TypeInferenceContext.new(tnode)
tnode.collect_candidate_type(context, [], [])
tnode.collect_candidate_type(context, [], [])

context = VM::CompileContext.new(tnode)
tnode.compile(context)
p tnode.code_space


