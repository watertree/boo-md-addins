namespace UnityScript.Ide.Tests

import NUnit.Framework
import UnityScript.Ide

[TestFixture]
class MethodsTest:
	
	[Test]
	def ReturnsCorrectNumberOfOverloads():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		code = """
class Foo{
	function blah(){
		var foo = new System.Collections.Generic.List.<int>();
		foo.CopyTo();
	}
}
"""
		methods = index.MethodsFor("foo.js", code, "CopyTo", 5)
		Assert.AreEqual(3, methods.Count) # List<>.CopyTo has 3 overloads

	[Test]
	def ReturnsNoMethodsWhenInvalid():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		code = """
class Foo{
	function blah(){
		var foo = 5;
		foo.ThisMethodDoesNotAndNeverWillExist();
	}
}
"""
		methods = index.MethodsFor("foo.js", code, "ThisMethodDoesNotAndNeverWillExist", 5)
		Assert.AreEqual(0, methods.Count)
		