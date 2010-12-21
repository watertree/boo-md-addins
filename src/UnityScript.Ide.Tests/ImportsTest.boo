namespace UnityScript.Ide.Tests

import System.Linq.Enumerable
import NUnit.Framework
import UnityScript.Ide

[TestFixture]
class ImportsTest:
	[Test]
	def ReturnsEmptyListForScriptWithNoImports():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		code = """
class Foo{}
"""
		index.Update("blah.js", code)
		imports = index.ImportsFor("blah.js", code)
		Assert.IsNotNull(imports)
		Assert.AreEqual(3, imports.Count())

	[Test]
	def ReturnsNonEmptyListForScriptWithImports():
		index = UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex()
		code = """
import System;
import System.Collections.Generic;
		
class Foo{}
"""
		index.Update("blah.js", code)
		imports = index.ImportsFor("blah.js", code)
		Assert.IsNotNull(imports)
		Assert.AreEqual(5, imports.Count())