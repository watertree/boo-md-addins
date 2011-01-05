namespace Boo.Ide.Tests

import NUnit.Framework

import Boo.Ide
import Boo.Lang.Compiler.MetaProgramming

[TestFixture]
class DotCompletionTest:
	
	[Test]
	def ProposalsForTypeInferredLocalVariable():
		
		code = """
			class Foo:
				def Bar():
					pass
					
			f = Foo()
			f.$CursorLocation
		"""
		
		proposals = ProposalsFor(code)
		expected = ("Bar",) + SystemObjectMemberNames()
		AssertProposalNames(expected, proposals)
		
	[Test]
	def ProposalsForTypeReferenceIncludeOnlyStaticMethods():
		code = """
			class Foo:
				static def NewInstance() as Foo:
					pass
				def Bar():
					pass
			Foo.$CursorLocation
		"""
		proposals = ProposalsFor(code)
		expected = ("NewInstance", "Equals", "ReferenceEquals")
		AssertProposalNames(expected, proposals)
		
	[Test]
	def ProposalsForNamespace():
		
		code = [|
			namespace MyLib
			class Foo:
				pass
		|]
		index = ProjectIndex()
		index.AddReference(compile(code))
		proposals = index.ProposalsFor("code.boo", "MyLib.$CursorLocation")
		AssertProposalNames(("Foo",), proposals)
		
	[Test]
	def ProposalsForInterfacesIncludeSuperInterfaceMembers():
		index = ProjectIndex()
		index.AddReference(typeof(ISub).Assembly)
		
		code = ReIndent("""
		v as $(typeof(ISub).BooTypeName())
		v.$CursorLocation
		""")
		proposals = index.ProposalsFor("code.boo", code)
		expected = ("SubMethod", "SuperMethod") + SystemObjectMemberNames()
		AssertProposalNames(expected, proposals)
		
	interface ISuper:
		def SuperMethod()
		
	interface ISub(ISuper):
		def SubMethod()
		
	[Test]
	def ProposalsForSubClassDontIncludeInaccessibleMembersFromSuper():
		
		code = """
			class Super:
				def Foo():
					pass
				private def Bar(): 
					pass
					
			class Sub(Super):
				def constructor():
					self.$CursorLocation # can't access Bar from here
		"""
		
		proposals = ProposalsFor(code)
		expected = ("Foo",) + SystemObjectMemberNames()
		AssertProposalNames(expected, proposals)
		
	[Test]
	def ProposalsForOverloadedMethodsAppearOnlyOnceAsAnAmbiguousEntity():
		code = """
			class Super:
				virtual def Foo():
					pass
					
			class Sub(Super):
				override def Foo():
					pass
				
				def Foo(value as int):
					pass
					
			Sub().$CursorLocation
		"""
		proposals = ProposalsFor(code)
		expected = ("Foo",) + SystemObjectMemberNames()
		AssertProposalNames(expected, proposals)
		
	[Test]
	def ProposalsDontIncludeSpeciallyNamedMethods():
		index = ProjectIndex()
		index.AddReference(typeof(TypeWithSpecialMembers).Assembly)
		proposals = index.ProposalsFor("code.boo", "$(typeof(TypeWithSpecialMembers).BooTypeName())().$CursorLocation")
		expected = ("Name", "NameChanged") + SystemObjectMemberNames()
		AssertProposalNames(expected, proposals)
		
	class TypeWithSpecialMembers:
		Name:
			get: return ""
		event NameChanged as System.EventHandler
	
	[Test]
	def ProposalsForTypeInReferencedAssembly():
		
		subject = ProjectIndex()
		subject.AddReference(typeof(Foo).Assembly)
		
		proposals = subject.ProposalsFor("code.boo", "$(typeof(Foo).BooTypeName())().$CursorLocation")
		
		expected = ("Bar",) + SystemObjectMemberNames()
		AssertProposalNames(expected, proposals)
		
	class Foo:
		def Bar():
			pass
			
[Extension] def BooTypeName(this as System.Type):
	return this.FullName.Replace('+', '.')
		
def ProposalsFor(code as string):
	index = ProjectIndex()
	return index.ProposalsFor("code.boo", ReIndent(code))
		
def AssertProposalNames(expected as (string), actual as (CompletionProposal)):
	actualNames = array(p.Entity.Name for p in actual)
	System.Array.Sort(expected)
	System.Array.Sort(actualNames)
	Assert.AreEqual(expected, actualNames)
	
