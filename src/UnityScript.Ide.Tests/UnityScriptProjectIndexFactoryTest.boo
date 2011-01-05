namespace UnityScript.Ide.Tests

import System.Reflection

import NUnit.Framework
import UnityScript.Ide

import Boo.Ide
import Boo.Ide.Tests

[TestFixture]
class UnityScriptProjectIndexFactoryTest:
	
	[Test]
	def ProposalsForUnityScriptCode():
		
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		proposals = index.ProposalsFor("code.js", "class Foo { function Bar() {} }; new Foo().$CursorLocation")
		expected = ("Bar",) + SystemObjectMemberNames()
		AssertProposalNames(expected, proposals)
		
	[Test]
	def ParseReturnsCodeWithUnityScriptSemantics():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		module = index.Parse("Code.js", "function foo() {}")
		expected = [|
			import UnityEngine
			import UnityEditor
			import System.Collections
			
			partial public class Code(Object):
				public virtual def foo() as void:
					pass
				public virtual def Main() as void:
					pass
				public def constructor():
					super()
		|]
		Assert.AreEqual(expected.ToCodeString(), module.ToCodeString())
		
	[Test]
	def ProposalsForExternalReferences():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		index.AddReference(Assembly.Load("System.Xml"))
		code = """
import System.Xml;

class Foo
{
	static function foo() {
		new XmlDocument().$CursorLocation
	}
}
"""
		proposals = index.ProposalsFor("code.js", code)
		for proposal in proposals:
			if(proposal.Entity.Name == "CreateXmlDeclaration"): return
		Assert.Fail("CreateXmlDeclaration not found in XmlDocument")
		
	[Test]
	def ProposalsForThis():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		code = """
	function foo() {
		this.$CursorLocation
	}
"""
		proposals = index.ProposalsFor("code.js", code)
		expected = ("foo",) + MonoBehaviourMemberNames()
		AssertProposalNames(expected, proposals)
		
		
	[Test]
	def ProposalsForMembersOfImplicitlyImportedTypes():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		code = """
class Foo
{
	function foo() {
		ArrayList.$CursorLocation
	}
}
"""
		proposals = index.ProposalsFor("code.js", code)
		expected = ["Adapter","Synchronized","ReadOnly","FixedSize","Repeat","Equals","ReferenceEquals"].ToArray(typeof(string))
		AssertProposalNames(expected, proposals)
		
	[Test]
	def ProposalsForTypeReferenceIncludeOnlyStaticMethods():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		code = """
			class Foo {
				static function NewInstance(): Foo { return null; }
				function Bar(){}
			}
			Foo.$CursorLocation
		"""
		proposals = index.ProposalsFor("code.js", code)
		expected = ("NewInstance", "Equals", "ReferenceEquals")
		AssertProposalNames(expected, proposals)
