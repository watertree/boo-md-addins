namespace Boo.MonoDevelop.Util.Completion

import System
import System.Linq
import System.Linq.Enumerable
import System.Threading
import System.Reflection
import System.Text.RegularExpressions
import System.Collections.Generic

import Boo.Lang.PatternMatching
import Boo.Lang.Compiler.TypeSystem

import Mono.TextEditor
import MonoDevelop.Projects
import MonoDevelop.Projects.Dom
import MonoDevelop.Projects.Dom.Output
import MonoDevelop.Projects.Dom.Parser 
import MonoDevelop.Ide
import MonoDevelop.Ide.Gui
import MonoDevelop.Ide.Gui.Content
import MonoDevelop.Ide.CodeCompletion
import MonoDevelop.Core
import MonoDevelop.Components
import MonoDevelop.Components.Commands

import Boo.Ide
import Boo.MonoDevelop.Util

class BooCompletionTextEditorExtension(CompletionTextEditorExtension,IPathedDocument):
	
	_dom as ProjectDom
	_project as DotNetProject
	_index as ProjectIndex
	
	public event PathChanged as EventHandler of DocumentPathChangedEventArgs
	
	# Match imports statement and capture namespace
	static IMPORTS_PATTERN = /^\s*import\s+(?<namespace>[\w\d]+(\.[\w\d]+)*)?\.?\s*/
	
	# Only lookup "Go to" once
	static gotoBase = GettextCatalog.GetString ("Go to Definition ({0})")
	
	override def Initialize():
		super()
		_dom = ProjectDomService.GetProjectDom(Document.Project) or ProjectDomService.GetFileDom(FileName)
		_project = Document.Project as DotNetProject
		_index = ProjectIndexFor(_project)
		textEditorData = Document.Editor
		UpdatePath(null, null)
		textEditorData.Caret.PositionChanged += UpdatePath
		Document.DocumentParsed += { UpdatePath(null, null) }
		
	abstract def ShouldEnableCompletionFor(fileName as string) as bool:
		pass
		
	abstract def GetParameterDataProviderFor(methods as Boo.Lang.List of MethodDescriptor) as IParameterDataProvider:
		pass
		
	abstract SelfReference as string:
		get
		
	abstract EndStatement as string:
		get
		
	abstract Keywords as (string):
		get
		
	abstract Primitives as (string):
		get
		
	private _currentPath as (PathEntry)
		
	public CurrentPath as (PathEntry):
		get:
			return _currentPath
		private set:
			_currentPath = value
		
	def ProjectIndexFor(project as DotNetProject):
		return ProjectIndexFactory.ForProject(project)
		
	override def ExtendsEditor(doc as MonoDevelop.Ide.Gui.Document, editor as IEditableTextBuffer):
		return ShouldEnableCompletionFor(doc.Name)
		
	override def HandleParameterCompletion(context as CodeCompletionContext, completionChar as char):
		if completionChar != char('('):
			return null
			
		methodName = GetToken(context)
		code = "${GetText(0, context.TriggerOffset)})\n${GetText(context.TriggerOffset+1, TextLength)}"
		line = context.TriggerLine
		filename = FileName
		
		try:
			methods = _index.MethodsFor(filename, code, methodName, line)
		except e:
			MonoDevelop.Core.LoggingService.LogError("Error getting methods", e)
			methods = Boo.Lang.List of MethodDescriptor()
			
		return GetParameterDataProviderFor(methods)
		
	override def CodeCompletionCommand(context as CodeCompletionContext):
		pos = context.TriggerOffset
		list = HandleCodeCompletion(context, GetText(pos-1, pos)[0])
		if list is not null:
			return list
		return CompleteVisible(context)
		
	def GetToken(location as DocumentLocation) as string:
		line = GetLineText(location.Line)
		offset = location.Column
		if(3 > offset or line.Length+1 < offset):
			return line.Trim()
			
		i = 0
		tokenStart = false
		for i in range(offset-3, -1, -1):
			if not char.IsWhiteSpace(line[i]):
				tokenStart = true
			if tokenStart and not (char.IsLetterOrDigit(line[i]) or '_' == line[i]):
				break
		if (0 == i and (char.IsLetterOrDigit(line[i]) or '_' == line[i])):
			start = 0
		else: start = i+1
		
		for i in range(offset-2, line.Length):
			if not (char.IsLetterOrDigit(line[i]) or '_' == line[i]):
				break
		end = i
		if (start < end):
			return line[start:end].Trim()
		return string.Empty
		
	def GetToken(context as CodeCompletionContext) as string:
		return GetToken (DocumentLocation (context.TriggerLine, context.TriggerLineOffset))
		
	def AddGloballyVisibleAndImportedSymbolsTo(result as BooCompletionDataList):
		ThreadPool.QueueUserWorkItem() do:
			namespaces = Boo.Lang.List of string() { string.Empty }
			for ns in _index.ImportsFor(FileName, Text):
				namespaces.AddUnique(ns)
			callback = def():
				result.IsChanging = true
				seen = {}
				for ns in namespaces:
					for member in _dom.GetNamespaceContents(ns, true, true):
						if member.Name in seen:
							continue
						seen.Add(member.Name, member)
						result.Add(CompletionData(member.Name, member.StockIcon))
				result.IsChanging = false
			DispatchService.GuiDispatch(callback)
		return result
		
	virtual def CompleteNamespacesForPattern(context as CodeCompletionContext, pattern as Regex, \
		                                     capture as string, filterMatches as MonoDevelop.Projects.Dom.MemberType*):
		lineText = GetLineText(context.TriggerLine)
		matches = pattern.Match(lineText)
		
		if not matches.Success:
			return null
			
		if context.TriggerLineOffset <= matches.Groups[capture].Index + matches.Groups[capture].Length:
			return null
			
		nameSpace = matches.Groups[capture].Value
		result = BooCompletionDataList()
		seen = {}
		for member in _dom.GetNamespaceContents(nameSpace, true, true):
			if member.Name in seen:
				continue
			if member.MemberType not in filterMatches:
				continue
			seen.Add(member.Name, member)
			result.Add(CompletionData(member.Name, member.StockIcon))
		return result
		
	def CompleteMembers(context as CodeCompletionContext):
		text = string.Format ("{0}{1} {2}", GetText (0, context.TriggerOffset),
		                                    Boo.Ide.CursorLocation,
		                                    GetText (context.TriggerOffset, TextLength))
		# print text
		return CompleteMembersUsing(context, text, null)
		
	def CompleteMembersUsing(context as CodeCompletionContext, text as string, result as BooCompletionDataList):
		if result is null: result = BooCompletionDataList()
		proposals = _index.ProposalsFor(FileName, text)
		for proposal in proposals:
			member = proposal.Entity
			result.Add(CompletionData(member.Name, IconForEntity(member), proposal.Description))
		return result
		
	def CompleteVisible(context as CodeCompletionContext):
		completions = BooCompletionDataList(IsChanging: true, AutoSelect: false)
		completions.AddRange(CompletionData(k, Stock.Literal) for k in Keywords)
		completions.AddRange(CompletionData(p, Stock.Literal) for p in Primitives)
		text = string.Format ("{0}{1}.{2}{3} {4}", GetText (0, context.TriggerOffset-1),
		                                    SelfReference, Boo.Ide.CursorLocation, EndStatement,
		                                    GetText (context.TriggerOffset+1, TextLength))
		
		# Add members
		CompleteMembersUsing(context, text, completions)
			
		# Add globally visible
		AddGloballyVisibleAndImportedSymbolsTo(completions)
		work = def():
			locals = _index.LocalsAt(FileName.FullPath, text, context.TriggerLine-1)
			if len(locals) == 0:
				callback = def():
					completions.IsChanging = false
			else:
				callback = def():
					completions.IsChanging = true
					completions.AddRange(CompletionData(local, Stock.Field) for local in locals)
					completions.IsChanging = false
			DispatchService.GuiDispatch(callback)
		ThreadPool.QueueUserWorkItem (work)
		
		return completions
		
	def StartsIdentifier(line as string, offset as int):
		startsIdentifier = false
		return false if (0 >= offset or offset >= line.Length)
		
		completionChar = line[offset]
		
		if(CanStartIdentifier(completionChar)):
			prevChar = line[offset-1]
			startsIdentifier = not (CanStartIdentifier(prevChar) or "."[0] == prevChar) # There's got to be a better way to do this
				
		return startsIdentifier
		
	def CanStartIdentifier(c as char):
		return char.IsLetter(c) or "_"[0] == c
		
	virtual def IsInsideComment(line as string, offset as int):
		tag = MonoDevelop.Projects.LanguageBindingService.GetBindingPerFileName(FileName).SingleLineCommentTag
		index = line.IndexOf(tag)
		return 0 <= index and offset >= index
		
	protected def GetLineText(line as int):
		line = Math.Max (0, line)
		line = Math.Min (TextEditor.LineCount-1, line)
		return TextEditor.GetLineText(line)
		
	protected def GetText(begin as int, end as int):
		end = Math.Min (TextLength-1, end)
		begin = Math.Max (0, begin)
		
		if (not end > begin):
			return string.Empty
		return TextEditor.GetTextBetween (begin, end)
		
	protected TextLength:
		get: return TextEditor.Length
		
	protected Text:
		get: return TextEditor.Text
		
	protected TextEditor:
		get: return Document.Editor
		
	protected FileName:
		get: return Document.FileName
		
	def CreatePathWidget(index as int) as Gtk.Widget:
		path = CurrentPath
		if(path == null or index < 0 or index >= path.Length):
			return null
		
		tag = path[index].Tag
		provider = null
		if(tag isa ICompilationUnit):
			provider = CompilationUnitDataProvider(Document)
		else:
			provider = DataProvider(Document, tag, GetAmbience())
			
		window = DropDownBoxListWindow(provider)
		window.SelectItem(tag)
		return window
		
	protected virtual def OnPathChanged(args as DocumentPathChangedEventArgs):
		if(PathChanged != null):
			PathChanged(self, args)
			
	def UpdatePath(sender as object, args as Mono.TextEditor.DocumentLocationEventArgs):
		unit = Document.CompilationUnit
		if(unit == null):
			return
			
		location = TextEditor.Caret.Location
		type = unit.GetTypeAt(location.Line, location.Column)
		result = System.Collections.Generic.List of PathEntry()
		ambience = GetAmbience()
		member = null
		node = unit as INode
		
		if(type != null and type.ClassType != ClassType.Delegate):
			member = type.GetMemberAt(location.Line, location.Column)
			
		if(member != null):
			node = member
		elif(type != null):
			node = type
			
		while(node != null):
			entry as PathEntry
			if(node isa ICompilationUnit):
				if(not Document.ParsedDocument.UserRegions.Any()):
					break
				region = Document.ParsedDocument.UserRegions.Where({r as FoldingRegion| r.Region.Contains(location.Line, location.Column) }).LastOrDefault()
				if(region == null):
					entry = PathEntry(GettextCatalog.GetString("No region"))
				else:
					entry = PathEntry(CompilationUnitDataProvider.Pixbuf, region.Name)
				entry.Position = EntryPosition.Right
			else:
				entry = PathEntry(ImageService.GetPixbuf((node as MonoDevelop.Projects.Dom.IMember).StockIcon, Gtk.IconSize.Menu), ambience.GetString((node as MonoDevelop.Projects.Dom.IMember), OutputFlags.IncludeGenerics | OutputFlags.IncludeParameters | OutputFlags.ReformatDelegates))
			entry.Tag = node
			result.Insert(0, entry)
			node = node.Parent
			
		noSelection as PathEntry = null
		if(type == null):
			noSelection = PathEntry(GettextCatalog.GetString("No selection"))
			noSelection.Tag = CustomNode(Document.CompilationUnit)
		elif(member == null and type.ClassType != ClassType.Delegate):
			noSelection = PathEntry(GettextCatalog.GetString("No selection"))
			noSelection.Tag = CustomNode(type)
			
		if(noSelection != null):
			result.Add(noSelection)
			
		prev = CurrentPath
		CurrentPath = result.ToArray()
		OnPathChanged(DocumentPathChangedEventArgs(prev))
		
	# Generate display text for a given token location,
	# so we can display "Go to DisplayTextForLocation" 
	# instead of "Go to definition"
	static def DisplayTextForLocation (location as TokenLocation) as string:
		if location != null:
			if not string.IsNullOrEmpty (location.File):
				return location.Name
			if not string.IsNullOrEmpty (location.TypeName):
				return location.TypeName
			if location.MemberInfo != null:
				match location.MemberInfo.Name:
					case /.c[c]?tor/:
						return location.MemberInfo.DeclaringType.Name
					otherwise:
						return location.MemberInfo.Name
		return null
		
	private def GetLocation ():
		line = GetLineText (Editor.Caret.Line)
		column = Editor.Caret.Column 
		
		# Account for tab width in boo parser
		# This will be removed later
		tabwidth = 7
		if (Document.FileName.Extension == ".boo"):
			tabwidth = 3
		column += (line.Where({ c | c == "\t"[0] }).Count() * tabwidth)
		
		return _index.TargetOf (Document.FileName.FullPath, Editor.Text, Editor.Caret.Line, column)
		
	[CommandUpdateHandler(MonoDevelop.Refactoring.RefactoryCommands.GotoDeclaration)]
	def CanGotoDeclaration (item as CommandInfo):
		location = null as TokenLocation
		try:
			location = GetLocation ()
		except e as ArgumentException:
			pass
			# LoggingService.LogError ("Error looking up target", e)
		item.Visible = (location != null)
		item.Bypass = not item.Visible
		
		if (location != null):
			displayText = DisplayTextForLocation (location)
			if not string.IsNullOrEmpty (displayText):
				item.Text = string.Format (gotoBase, displayText)
		
	[CommandHandler(MonoDevelop.Refactoring.RefactoryCommands.GotoDeclaration)]
	def GotoDeclaration ():
		location = null as TokenLocation
		try:
			location = GetLocation ()
			# Console.WriteLine (location)
		except e as ArgumentException:
			LoggingService.LogError ("Error looking up target", e)
		if (location is null):
			# Console.WriteLine ("No target!")
			return
		elif (location.MemberInfo != null):
			# Console.WriteLine ("Attempting to lookup member info {0}", location.MemberInfo.Name)
			declaringType = location.MemberInfo.DeclaringType
			if (declaringType.IsGenericType):
				declaringType = declaringType.GetGenericTypeDefinition ()
			type = _dom.GetType (declaringType.FullName, 0, true, true) as MonoDevelop.Projects.Dom.IType
			if (type != null):
				member = type.Members.FirstOrDefault ({ m | MembersAreEqual (location.MemberInfo, m) })
				if not (member is null):
					# Console.WriteLine ("Jumping to {0}", member.FullName)
					IdeApp.ProjectOperations.JumpToDeclaration (member)
			# else: Console.WriteLine ("Null type lookup for {0}", declaringType.FullName)
		elif (location.TypeName != null):
			# Console.WriteLine ("Jumping to {0}", location.TypeName)
			IdeApp.ProjectOperations.JumpToDeclaration (_dom.GetType (location.TypeName, 0, true, true) as MonoDevelop.Projects.Dom.IType)
		else:
			# Console.WriteLine ("Jumping to {0}", location.Name)
			IdeApp.Workbench.OpenDocument (location.File, location.Line, location.Column, OpenDocumentOptions.HighlightCaretLine)
			
	static def MembersAreEqual(memberInfo as MemberInfo, imember as MonoDevelop.Projects.Dom.IMember):
		# Console.WriteLine ("Checking {0}", imember.FullName)
		if not (memberInfo.Name.Equals (imember.Name, StringComparison.Ordinal) or \
		(memberInfo.Name.Equals (".ctor", StringComparison.Ordinal) and imember.Name.Equals ("constructor", StringComparison.Ordinal))):
			# Console.WriteLine ("{0} != {1}", memberInfo.Name, imember.Name)
			return false
		
		if (memberInfo isa MethodBase):
			if not imember isa MonoDevelop.Projects.Dom.IMethod:
				# Console.WriteLine ("IMember is not IMethod")
				return false
			methodbase = memberInfo as MethodBase
			imethod = imember as MonoDevelop.Projects.Dom.IMethod
			mbparams = methodbase.GetParameters()
			imparams = imethod.Parameters
			
			if (mbparams.Length != imparams.Count): return false
			found = range(mbparams.Length).Any () do (i):
				# Console.WriteLine ("Comparing {0}({2}) to {1}", imparams[i].ReturnType.FullName, mbparams[i].ParameterType.FullName, imparams[i].ReturnType.GetType ())
				
				# Check imparams for generic
				if (imparams[i].ReturnType isa DomReturnType and \
				(imparams[i].ReturnType as DomReturnType).GenericArguments.Count > 0):
					return false 
					
				# Check mbparams for generic
				if (mbparams[i].ParameterType.IsGenericParameter):
					return false
					
				# Compare names
				if (imparams[i].ReturnType.FullName.Equals (mbparams[i].ParameterType.FullName)):
					return false
			if found:
				# Console.WriteLine ("Parameter mismatch")
				return false
		return true
		

class CustomNode(AbstractNode):
	def constructor(parent as INode):
		Parent = parent

def IconForEntity(member as IEntity) as MonoDevelop.Core.IconId:
	match member.EntityType:
		case EntityType.BuiltinFunction:
			return Stock.Method
		case EntityType.Constructor:
			return Stock.Method
		case EntityType.Method:
			return Stock.Method
		case EntityType.Local:
			return Stock.Field
		case EntityType.Field:
			return Stock.Field
		case EntityType.Property:
			return Stock.Property
		case EntityType.Event:
			return Stock.Event
		case EntityType.Type:
			type as Boo.Lang.Compiler.TypeSystem.IType = member
			if type.IsEnum: return Stock.Enum
			if type.IsInterface: return Stock.Interface
			if type.IsValueType: return Stock.Struct
			return Stock.Class
		case EntityType.Namespace:
			return Stock.NameSpace
		case EntityType.Ambiguous:
			ambiguous as Ambiguous = member
			return IconForEntity(ambiguous.Entities[0])
		otherwise:
			return Stock.Literal

	
