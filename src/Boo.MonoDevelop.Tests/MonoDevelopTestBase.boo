namespace Boo.MonoDevelop.Tests

import System
import System.IO
import NUnit.Framework
import MonoDevelop
import MonoDevelop.Projects.Dom.Parser
import MonoDevelop.Ide
import Gtk from "gtk-sharp" as Gtk

class MonoDevelopTestBase:

	static firstRun = true
	
	[TestFixtureSetUp]
	virtual def SetUp():
		if not firstRun:
			return
			
		firstRun = false
		
		Core.Runtime.Initialize(true)
		Gtk.Application.Init()
		ProjectDomService.TrackFileChanges = true
		DesktopService.Initialize()
		MonoDevelop.Projects.Services.ProjectService.DefaultTargetFramework = Core.Runtime.SystemAssemblyService.GetTargetFramework("2.0")
		
	[TestFixtureTearDown]
	virtual def TearDown():
		pass
