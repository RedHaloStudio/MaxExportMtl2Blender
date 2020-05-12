--MAXTOBLENDER - based on MaxToBlender v2.0
--filein("C:\Program Files\Autodesk\3ds Max 2018\scripts\MaxToBlender\MaxToBlender.ms")

global rXMLExport
global xencrypt = 0
global xvalue  = 30
global userPath
--********** ENK  ************************************************
--********** ENK  ************************************************

global xml = undefined
global isZip = true
global proxyList = #()

global colMats = #()
global colMatsSub = #()
global mapFiles= #()
global allMats= #()
global listTexture = #()

global root01
global root02
global root03
global root04 = undefined
global root05
global root07
global root08
global root09
global root20
global root21
global root23
global root24
global root1
global tempPath=sysInfo.tempdir 
global userPath= (substituteString tempPath "AppData\\Local\\Temp\\" "") +"Documents\\TEMP3D"		
global userDefaultPath = userPath+""


global scriptPath = getfilenamePath (getThisScriptFilename())
global rMAC

xmlDoc = dotNetObject "system.xml.xmlDocument"
scriptpath = getfilenamePath (getThisScriptFilename())
print scriptpath
imagepath = scriptpath+"mtblogo.png"
srlimagepath = scriptpath+"mtblogosrl.png"
configpath = getfilenamePath (getThisScriptFilename())
configpath += "\\config.xml"
try(xmlDoc.load configpath)catch(print("config.xml skipped"))
data = xmlDoc.selectNodes "//config/exportfile"
global exportPath = ""

try 
(
	exportPath = data.itemof[0].attributes.Itemof["path"].value
)
catch()

if (exportPath != "") then
	userPath = exportPath

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
--FORCE USERPATH ALWAYS DOCS/TEMP3D
-- userPath = (substituteString tempPath "AppData\\Local\\Temp\\" "") +"Documents\\TEMP3D"	
userPath = "C:\TEMP3D"

-------------------------------------------------------------------------------------------
global targetPath = userPath
-------------------------------------------------------------------------------------------

global mathlib = dotnetclass "math"

global active_cam = getactivecamera() as string
	
global count_cam = 0
for cam in cameras do
	if (cam != Targetobject) then
		count_cam += 1



--********** ZIP STUFF ************************************************
struct zip
(
	--http://forums.cgsociety.org/showthread.php?t=800618
	--zip-struct based on code by Rene Baca, MerlinEl
	
	
	all_dirs = #(),
	zipThread = dotnetobject "CSharpUtilities.SynchronizingBackgroundWorker",
	
	sourceFolderPath,
	targetFolderPath,
	zipFileName = "zippy",
	useSubdirs = true,
	deleteOld = false,

	function fn_getDirTree dir =
	(
		--<FUNCTION>
		--Description:
		--	Recursively gets all directories from a root directory. Doesn't include the root
		--Arguments:
		--	<string> dir: the root directory to recursively get all child-directories from
		--Return:
		--	Stores an array of filepaths in an external array: all_dirs
		--</FUNCTION>*/
		
		all_dirs += curr_dirs = getDirectories (dir+"*")
		for i in curr_dirs do fn_getDirTree i
	),
	
	function fn_getAllFiles arrDir =
	(
		-- /*<FUNCTION>
		-- Description:
		-- 	Gets all files from an array of directories.
		-- Arguments:
		-- 	<array> arrDir: An array of directories
		-- Return:
		-- 	<array> an array of filepaths
		-- </FUNCTION>*/
		
		local arrFile = #()
		for theDir in arrDir do arrFile += getFiles (theDir + "*")
		arrFile
	),
	
	function fn_deleteOldFiles arrFile =
	(
		-- /*<FUNCTION>
		-- Description:
		-- 	Delete files.
		-- Arguments:
		-- 	<array> arrfile: an array of files which is to be deleted
		-- Return:
		-- 	<bool> Function returns (anything?).
		-- </FUNCTION>*/
		
		for i in arrFile do try deleteFile i catch (format "The file: %\tcannot be deleted.\n" i)
	),
	
	function fn_collectFiles sourceFolderPath: useSubdirs: =
	(
		-- /*<FUNCTION>
		-- Description:
		-- 	Collects files from a folder.
		-- Arguments:
		-- 	<string> sourceFolderPath: the path to the folder from which the contents needs to be zipped
		-- 	<boolean> useSubdirs: set to true when you want to get all contents of the sourcefolder and it's subfolders		
		-- Return:
		-- 	<array> An array of filepaths
		-- </FUNCTION>*/
		
		local all_files = #()

		--collecting source files
		all_files = getFiles (sourceFolderPath + "*") --root dir files
		if useSubdirs do --also collect files from subdirs, recursively
		(
			fn_getDirTree sourceFolderPath --collect all subdirs in dir in to local all_dirs
			if all_dirs.count != 0 do join all_files (fn_getAllFiles all_dirs) --collect files from subdirs
		)
		
		format "Number of files: %\n" all_files.count
		if all_files.count == 0 do (print "No files have been found";return false)
		
		all_files
	),
	
	
	function fn_createFileList arrFile listPath basePath =
	(
		-- /*<FUNCTION>
		-- Description:
		-- 	Creates a textfile which contains a filelist with paths relative to a basepath
		-- Arguments:
		-- 	<array> arrFile: an array of filepaths
		-- 	<string> listPath: the path to the textfile
		-- 	<string> basePath: the path to which the files need to be relative
		-- Return:
		-- </FUNCTION>*/
		
		--zipping multiple files is done by using a file-list. This list is stored as a text-file on disk
		--generate a file with the list of files to be archived
		if doesFileExist listPath do deleteFile listPath -- delete old tmp file if exist
		makeDir (getFilenamePath  listPath)
		local theTempFile		
		try (theTempFile = createFile listPath) catch (format "% cannot be created\n" listPath; return false)
		for i in arrFile do format "%\n" (substituteString i basePath "") to:theTempFile --slice off the common root. Only possible when working from a drive-letter, not a unc-path. Why? Unknown!
		flush theTempFile
		close theTempFile
	),
	
	
	function fn_zipFiles sourceFolderPath: targetFolderPath: zipFileName: useSubdirs:true deleteOld:false =
	(
		-- /*<FUNCTION>
		-- Description:
		-- 	packages files together in a zipfile. Uses the max-native maxzip.exe to perform the zipping.
		-- Arguments:
		-- 	<string> sourceFolderPath: the path to the folder from which the contents needs to be zipped
		-- 	<string> targetFolderPath: the folder where the zipfile has to be stored
		-- 	<string> zipFileName: the name of the zipfile
		-- 	<boolean> useSubdirs: set to true when you want to get all contents of the sourcefolder and it's subfolders
		-- 	<boolean> deleteOld: set this to true if you want to delete the original files after zipping them
		-- Return:
		-- 	<string> the path of the generated zipfile
		-- </FUNCTION>*/
		
		--reset the file and dir-containers
		local all_files = #()
		all_dirs = #()
		
		--error check to see if the specified paths exists
		if not doesFileExist sourceFolderPath do (format "% does not exist\n" sourceFolderPath;return false)
		if not doesFileExist targetFolderPath do (format "% does not exist\n" targetFolderPath;return false)
		
		--check if the folderpaths end with a backslash. Add it if needed.
		if substring sourceFolderPath 1 -1 != "\\" do sourceFolderPath += "\\"
		if substring targetFolderPath 1 -1 != "\\" do targetFolderPath += "\\"
			
		--collect the files
		all_Files = fn_collectFiles sourceFolderPath:sourceFolderPath useSubdirs:useSubdirs
		if all_files == false do return false
			
		--create the file-list
		local theTempFilePath = @"C:/temp/maxzip.tmp" --need a path without any spaces!!
		fn_createFileList all_files theTempFilePath sourceFolderPath
		
		-- archive the files stored in the file-list into the zip
		local curDir = sysInfo.currentDir -- store current system dir
		local zipUtil = (getDir #maxRoot) + "maxzip.exe" --this is the actual zipping-program
		local zipFile = targetFolderPath + zipFileName + ".3ta"
		local cmd = "" as stringStream --set up a zipping-command
		format "\"%\" \"%\" @%" zipUtil zipFile theTempFilePath to:cmd -- thanks to ofer_z--zipFile needs to be a mapped drive?
		sysInfo.currentDir = sourceFolderPath-- set system folder (zip tree begins here)
		(hiddendosCommand cmd exitcode:&exitcode) --EXECUTE THE ZIPPING
		sysInfo.currentDir = curDir -- restore old system dir
		
		-- delete the temp file list
-- 		deleteFile theTempFilePath
		--delete old files if is true
		if deleteOld do fn_deleteOldFiles all_files
		
		--output the code returned by maxzip. For a list of possible codes, check here: http://www.info-zip.org/mans/zip.html under DIAGNOSTICS
		format "status:%\n" exitcode
		
		zipfile --return the path of the zipfile
	),
	
	function event_workZipThread control arg =
	(
		-- /*<FUNCTION>
		-- Description:
		-- 	This event executes the zip in a separate thread. The result is passed onto a different event.
		-- Arguments:
		-- Return:
		-- </FUNCTION>*/
		
		zip.fn_zipFiles sourceFolderPath:zip.sourceFolderPath targetFolderPath:zip.targetFolderPath zipFileName:zip.zipFileName useSubdirs:zip.useSubdirs deleteOld:zip.deleteOld
	),
	
	function fn_initZipThread theTread =
	(
		-- /*<FUNCTION>
		-- Description:
		-- 	initializes the event-handlers for the zip-thread
		-- Arguments:
		-- 	<thread> theThread: the thread which needs to be initialized
		-- Return:
		-- </FUNCTION>*/
		
		--Initialise event handlers
		theTread.WorkerSupportsCancellation = true
		theTread.WorkerReportsProgress = true
		dotNet.addEventHandler theTread "DoWork" event_workZipThread
		if theTread.IsBusy do theTread.CancelAsync()		
	),
	
	init = fn_initZipThread zipThread
	
)
--*********************************************************************

-- SERIAL STUFF START --------------------------------------------------------------------

fn getMACAddress =
(
	NWIF = dotnetClass "System.Net.NetworkInformation.NetworkInterface"
	the_Mac_array = NWIF.GetAllNetworkInterfaces() -- this is an array of all the Networks
	the_PhysicalAddress_Array = #()
	for net in the_Mac_array where (net.NetworkInterfaceType.toString()) == "Ethernet" do append the_PhysicalAddress_Array ((net.GetPhysicalAddress()).toString())
	return (the_PhysicalAddress_Array	[1])
)

function compareKey key mac =
(
	-- print mac
	if key[4] == mac[3] and key[6] == mac[4] and key[10] == mac[mac.count-2] and key[12] == mac[mac.count-1] then
		return true
	else 
		return false
)

function randomKey key =
(
	local alphabet = "abcdefghijklmnopqrstuvxyz0123456789"
	local newkey = ""
	for i = 1 to 13 do
		newkey += alphabet[random 1 alphabet.count]
	newkey[4] = key[3]
	newkey[5] = key[4]
	newkey[9] = key[key.count-2]
	newkey[10] = key[key.count-1]
	return newkey
)

function getLicenseKey key =
(
	local value1 = ""
	registry.openKey HKEY_CURRENT_USER key accessRights:#all key:&key1
	if key1 != undefined then
		registry.queryValue key1 "license_maxtoblenderV2" type:#REG_SZ value:&value1 expand:false
	return value1
)

function setLicenseKey key val =
(
	registry.openKey HKEY_CURRENT_USER key accessRights:#all key:&key1
	registry.createKey HKEY_CURRENT_USER key accessRights:#all newKeyCreated:&newKeyCreated key:&key1
	registry.setValue key1 "license_maxtoblenderV2" #REG_SZ val
)

function getRegistryKey key subkey=
(
	local value1 = ""
	registry.openKey HKEY_CURRENT_USER key accessRights:#all key:&key1
	if key1 != undefined then
		registry.queryValue key1 subkey type:#REG_SZ value:&value1 expand:false
	return value1
)

function setRegistryKey key subkey val =
(
	registry.openKey HKEY_CURRENT_USER key accessRights:#all key:&key1
	registry.createKey HKEY_CURRENT_USER key accessRights:#all newKeyCreated:&newKeyCreated key:&key1
	registry.setValue key1 subkey #REG_SZ val
)

function loadImage bt filepath =
(
	try(bt.images = #(filepath, undefined, 1,1,1,1,1 ))catch()
)

function maxVersionNumber =
(
	caca = GetFileVersion (getDir #maxRoot + "\\3dsmax.exe")
	maxVer = caca[1] + caca[2]
	currentMaxVer = maxVer as Integer
	currentMaxVer -= 2
	currentMaxVer += 2000
	return currentMaxVer
)
-- SERIAL STUFF END --------------------------------------------------------------------

function resetVrayLightScale l =
(
	try(
		currentScale = l.scale
		currentVLight0 = l.size0
		currentVLight1 = l.size1

		l.scale.x = 1
		l.scale.y = 1
		l.scale.z = 1

		l.size0 = l.size0 * currentScale.x
		l.size1 = l.size1 * currentScale.y
	)catch(
		print "ScaleReset skipped..."
		)

)

function fixVrayLightsScale =
(
	for l in lights do
	(
		print l.name
		resetVrayLightScale l
	)
)

function fixGroupMirror =
(
	for g in helpers do
	(
		if g.Scale.x < 0 or g.Scale.y < 0 or g.Scale.z < 0 then
		(
			ungroup  g
		)
	)
)
function simplifyVRay2SidedMtl =
(
	--HACER LO MISMO PARA 2Sided Standard .. prober en multimaterials etc..
	max select all
	for obj in selection do
	(
		try
		(
			if classOf obj.mat == VRay2SidedMtl then
			(
				tempMap = obj.mat.frontMtl
				obj.mat = tempMap
			)
		)catch()
	)
)

function simplyFalloff mat=
(
	materialType = classof mat
	mapType = ""
	print materialType
	if materialType == VRayMtl then
	(
		try ( mapType = classof mat.texmap_diffuse ) catch()
		if mapType == Falloff then
		(
			print "-------------------------------"
			print "VRAY Falloff"
			tempMap = mat.Diffuse_map.map1
			mat.texmap_diffuse = tempMap
		)
	)
	if materialType == Standardmaterial then
	(
		try ( mapType = classof mat.diffusemap ) catch()
		if mapType == Falloff then
		(
			print "-------------------------------"
			print "Standard - Falloff"
			tempMap = mat.diffusemap.map1
			mat.diffusemap = tempMap
		)
	)
	
	print mapType
	--tempMap = mat.Diffuse_map.map1
	--mat.texmap_diffuse = tempMap
)

function simplifyVRayDirt mat=
(
	materialType = classof mat
	mapType = ""
	--print materialType
	if materialType == VRayMtl then
	(
		try ( mapType = classof mat.texmap_diffuse ) catch()
		if mapType == VRayDirt then
		(
			print "-------------------------------"
			try(
				--print mat
				--print mat.texmap_diffuse.texmap_unoccluded_color.bitmap
				try ( mapType = classof mat.texmap_diffuse ) catch()
				tempMap = mat.texmap_diffuse.texmap_unoccluded_color
				mat.texmap_diffuse = tempMap
			)catch()
		)
	)
)

function simplyColorCorrect mat=
(
	--print (classof mat.Diffuse_map)
	materialType = classof mat
	mapType = ""
	print materialType
	if materialType == VRayMtl then
	(
		try ( mapType = classof mat.texmap_diffuse ) catch()
		if mapType == Color_Correction then
		(
			print "-------------------------------"
			print "VRAY Color Correction"
			tempMap = mat.Diffuse_map.map
			mat.texmap_diffuse = tempMap
		)
	)
	if materialType == VRayLightMtl then
	(
		try ( mapType = classof mat.texmap ) catch()
		if mapType == Color_Correction then
		(
			tempMap = mat.texmap.map
			mat.texmap = tempMap
		)
	)
	if materialType == Standardmaterial then
	(
		try ( mapType = classof mat.diffusemap ) catch()
		if mapType == Color_Correction then
		(
			print "-------------------------------"
			print "Standard - Color Correction"
			tempMap = mat.diffusemap.map
			mat.diffusemap = tempMap
		)
	)
	
	print mapType
	--tempMap = mat.Diffuse_map.map1
	--mat.texmap_diffuse = tempMap
)

function simplifyMAPS =
(
	--RUN THISSS SCRIPT AFTER BLENDRMATS SIMPLIFIED ETC...
	for mat in sceneMaterials do (
		simplifyVRayDirt mat
		simplyFalloff mat
		simplyColorCorrect mat
		--HACER LO MISMO PARA STANDAR MATSSS!!!
	)
)

function Base64Encode plainText =
(
	sysCon = dotnetClass "System.Convert"
	sysTextEnc = dotNetObject  "System.Text.UTF8Encoding"
	plainTextBytes = sysTextEnc.GetBytes plainText
	return sysCon.ToBase64String plainTextBytes
)
function Base64Decode base64EncodedData =
(
	sysCon = dotnetClass "System.Convert"
	sysTextEnc = dotNetObject  "System.Text.UTF8Encoding"
	base64EncodedBytes = sysCon.FromBase64String base64EncodedData
	return sysTextEnc.GetString base64EncodedBytes
)

function encode keyString xmlString baseEncode =
(
    local encoded_chars = #()
	
    for i = 0 to xmlString.count-1 do (
		
		stringIndex = i+1
        
		key_int = bit.CharAsInt keyString[ mod i keyString.count+1 ]
		xml_int = bit.CharAsInt xmlString[stringIndex]
		
		encoded_int_char = bit.IntAsChar (mod (xml_int + key_int) 256)
        
		append encoded_chars encoded_int_char
	)
    
	local encoded_string = ""
	
	for i = 1 to encoded_chars.count do encoded_string += encoded_chars[i]	
	
	if (baseEncode) then
		return Base64Encode encoded_string
	
	return encoded_string
)
function decode keyString encodedString baseEncoded  =
(
    local decoded_chars = #()
	
	if (baseEncoded) then
		encodedString = Base64Decode encodedString
	
    for  i = 0 to encodedString.count-1 do (
		
		stringIndex = i+1
		
		key_int = bit.CharAsInt keyString[ mod i keyString.count+1 ]
		char_as_int = bit.CharAsInt encodedString[stringIndex]
		
		unshifted_int = mod (char_as_int - key_int) 256
		unshifted = bit.IntAsChar (unshifted_int)
		
        append decoded_chars unshifted
	)
	
    local decoded_string = ""
	for i = 1 to decoded_chars.count do decoded_string += decoded_chars[i]		
	
	return decoded_string
)
function saveXML xml =
(
	-- key = "testkey"
	-- baseEncoded = false
	
	-- xmlString = xml.OuterXML	
	-- encodedString = encode key xmlString baseEncoded
	-- decodedString = decode key encodedString baseEncoded
	
	xml.save (userPath +"\\3dm2b.xml")

	-- out_name = (userPath+"\\material_encoded.3dt")
	-- out_file = createfile out_name
	-- format encodedString to:out_file
	-- close out_file



	
	-- out_name = (userPath+"\\material_decoded.3dt")
	-- out_file = createfile out_name
	-- format decodedString to:out_file
	-- close out_file
	
	-- print ("xml = "+xmlString)
	-- print ("enc = "+encodedString)
	-- print ("dec = "+decodedString)
)

function mayaNameFixes =
(
	mats = #()
	for matClass in material.classes do
	(
		for m in (getclassinstances matClass processChildren:true) do append mats m
	)
		 
	for mat in mats do
	(
		try(mat.name = substituteString mat.name " " "_")catch()
		try(mat.name = substituteString mat.name "-" "_")catch()
		try(mat.name = substituteString mat.name "#" "-")catch()
	)
)

function vrayNextGPUfix = 
(
	--VRAY NEXT GPU TO CPU FIX ============================================================
	currentRender = renderers.current as String
	if (findString currentRender "V_Ray_GPU_Next") != undefined then
	(
		try(renderers.current = V_Ray_Next())catch()
	)
	-- =========================================================================================
)

function vrayRTfix =
	(
	currentRend = renderers.current as string

	print currentRend as string
	caca = findString currentRend "_RT_"
	print caca
	if  caca != None then
	(
		for r in 1 to (rendererClass.classes).count where matchPattern ((rendererClass.classes)[r] as string) pattern:"V_Ray_Adv*" do
		(
			Renderers.Production = RendererClass.Classes[r]()
		)
		
	)
)

function doPatches =
	(
		local filename = getfilenamefile maxfilename
		
		if (findString filename "RetroGuitarAmp" != undefined) then
		(
			for geom in objects do
			(
				if geom.name == "body" then
				(
					Select geom
					geoms = #()
					geoms  +=geom
					fixMapping (geoms)
				)
			)
		)
	)

function simp_MakeUnique=
(
		global makeDifferent = 0
		matTypes = material.classes
		matArray = #()
		for cmt in matTypes do
		(
			tmpArr = getClassInstances cmt
			matArray = matArray + tmpArr
		)
		o = box()
		for cm in matArray do 
		(
			o.material = cm
			--print o.material.name
			--print (classof o.material)
			if classof o.material == Multimaterial then 
			(
				for m = 1 to o.material.numsubs do
				(
					if (isNeed2Standard o.material[m]) then
					(	
						local temp = o.material[m].name
						newMat = Standard()
						replaceInstances o.material[m] newMat
						o.material[m].diffuse = color 0 0 makeDifferent
						o.material[m].name = temp
						makeDifferent +=1
					)
					else
						try
						(
							o.material[m].shaderType = 1
						) catch ()
				)
			)
			else
			(
				if true then
				(	
					global temp = o.material.name
					if (classof o.material == VrayBlendMtl) or (classof o.material == Blend) then
					(
						print ("MAKEDIFFERENT = "+temp)
					)
					newMat = Standard()
					replaceInstances o.material newMat					
					o.material.diffuse = color 0 0 makeDifferent
					o.material.name = temp
					
					makeDifferent +=1
				)
			)
		)
		delete o
		listmat = collectAllSingleMaterial()
		global listj =#{}
		for i = 1 to listmat.count-1 do
		(
			global val = 0.01
			for j=i+1 to listmat.count do
				if (listj[i] == false and listj[j]==false ) then
				(
					if (listmat[i] == listmat[j]) then
						listj += #{j}
				)
		)
)	

function fixMapping sel  =
(
	for obj in sel do
	(
		i = 1
		lastSmoothMod = 0
		for modi in obj.modifiers do
		(
			i = modPanel.getModifierIndex obj modi
			if ((classOf modi == TurboSmooth) or (classOf modi == MeshSmooth)) then
			(
				lastSmoothMod = i
			)
		)
		max modify mode
		edPoly1 = Edit_Poly()
		if (lastSmoothMod>0) then
		(
			i=lastSmoothMod
			addModifier obj edPoly1 before:i
			i+=1
			modPanel.setCurrentObject obj.modifiers[i]
		) else (
			i = 1
			addModifier obj (edPoly1)
			modPanel.setCurrentObject obj.modifiers[i]
		)
		subObjectLevel = 2
		max select all
		proOpt = ProOptimizer ()
		modPanel.addModToSelection (proOpt)
		proOpt.KeepUV = on
		proOpt.Calculate = on
		edPoly2 = Edit_Poly()
		modPanel.addModToSelection (edPoly2)
		subobjectLevel = 2
		max select invert
		edPoly2.ButtonOp #RemoveEdge
		max modify mode
		maxOps.CollapseNodeTo obj (modPanel.getModifierIndex obj edPoly2) true
		if (obj.modifiers.count>0) then
		(
			modPanel.setCurrentObject obj.modifiers[1]
		)
		--obj.name = ("UVFIXED_"+obj.name)
	)
)

function int2String i prefix =
(
	local s = prefix
	if (i<10) then 
		s += "00"+i as string
	else
		if (i<100) then 
			s += "0"+i as string
	return s
)

function isHavingWeirdCharacter s =
(
	local ch = "abcdefghijklmnopqrstuvwxyz0123456789_.- ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i=1 to s.count do
		if (findString ch s[i] == undefined) then
			return true
	return false
)

function isStartingWithNumber s =
(
	local num = "0123456789"
	if (s=="") then
		return false
	if (findString num s[1] == undefined) then
		return false
	else
		return true
)

function FixWeirdCharacter s =
(
	local ch = "abcdefghijklmnopqrstuvwxyz0123456789_.- ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local ss = ""
	for i=1 to s.count do
		if (findString ch s[i] != undefined) then
			ss += s[i]
	return ss
)

fn GetMaps mapName = 
(
	case classof mapName of (
		
		bitmaptexture: (
			join mapFiles #( mapName )
			)

		cellular: (
			join mapFiles #( mapName )
			
			if mapName.cellmap != undefined do (
				if classof mapName.cellmap != Bitmaptexture then (
					GetMaps mapName.cellmap
					) else (
						join mapFiles #( mapName.cellmap )
						)
				)
			if mapName.divmap1 != undefined do (
				if classof mapName.divmap1 != Bitmaptexture then (
					GetMaps mapName.divmap1
					) else (
						join mapFiles #( mapName.divmap1 )
						)
				)
			if mapName.divmap2 != undefined do (
				if classof mapName.divmap2 != Bitmaptexture then (
					GetMaps mapName.divmap2
					) else (
						join mapFiles #( mapName.divmap2 )
						)
				)
			)
		
		Checker: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)
				
		ColorCorrection: (
			join mapFiles #( mapName )
			
			if mapName.map != undefined do (
				if classof mapName.map != Bitmaptexture then (
					GetMaps mapName.map
					) else (
						join mapFiles #( mapName.map )
						)
				)	
			)
			
		compositeTextureMap: (
			join mapFiles #( mapName )
			
			for b = 1 to mapName.maplist.count do (
				if classof mapName.maplist[b] != Bitmaptexture then (
					GetMaps mapName.maplist[b]
					) else (
						join mapFiles #( mapName.maplist[b] )
						)
				)
			for c = 1 to mapName.mask.count do (
				if classof mapName.mask[c] != Bitmaptexture then (
					GetMaps mapName.mask[c]
					) else (
						join mapFiles #( mapName.mask[c] )
						)
				)
			)
		
		dent: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)	
	
		Falloff: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
				
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)
			
		gradient: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)
			if mapName.map3 != undefined do (
				if classof mapName.map3 != Bitmaptexture then (
					GetMaps mapName.map3
					) else (
						join mapFiles #( mapName.map3 )
						)
				)
			)

		mask: (
			join mapFiles #( mapName )
			
			if mapName.map != undefined do (
				if classof mapName.map != Bitmaptexture then (
					GetMaps mapName.map
					) else (
						join mapFiles #( mapName.map )
						)
				)
			if mapName.mask != undefined do (
				if classof mapName.mask != Bitmaptexture then (
					GetMaps mapName.mask
					) else (
						join mapFiles #( mapName.mask )
						)
				)	
			)

		material_to_shader: (
			join mapFiles #( mapName )
			
			if mapName.material != undefined do ( 
				join mapFiles #( mapName.material )
				for a = 1 to ( getNumSubTexmaps mapName.material ) do (
					if ( ( getSubTexmap mapName.material a ) != undefined ) do (
						mapName2 = ( getSubTexmap mapName.material a )
						GetMaps mapName2
						)
					)
				)
			)
			
		mix: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)
			
		noise: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)
		
		VRayNormalMap: (
			join mapFiles #( mapName )
			
			if mapName.normal_map != undefined do (
				if classof mapName.normal_map != Bitmaptexture then (
					GetMaps mapName.normal_map
					) else (
						join mapFiles #( mapName.normal_map )
						)
				)
			)
		
		Normal_Bump: (
			join mapFiles #( mapName )
			
			if mapName.normal_map != undefined do (
				if classof mapName.normal_map != Bitmaptexture then (
					GetMaps mapName.normal_map
					) else (
						join mapFiles #( mapName.normal_map )
						)
				)
			if mapName.bump_map != undefined do (
				if classof mapName.bump_map != Bitmaptexture then (
					GetMaps mapName.bump_map
					) else (
						join mapFiles #( mapName.bump_map )
						)
				)	
			)
		
		output: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			)
			
		perlinMarble: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)	
		
		rgbMult: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)
			
		Smoke: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)
			
		Speckle: (
			join mapFiles #( mapName )
			
			if mapName.MAP1 != undefined do (
				if classof mapName.MAP1 != Bitmaptexture then (
					GetMaps mapName.MAP1
					) else (
						join mapFiles #( mapName.MAP1 )
						)
				)
			if mapName.MAP2 != undefined do (
				if classof mapName.MAP2 != Bitmaptexture then (
					GetMaps mapName.MAP2
					) else (
						join mapFiles #( mapName.MAP2 )
						)
				)	
			)
			
		Splat: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)
			
		Stucco: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)	
			
		Stucco: (
			join mapFiles #( mapName )
			
			if mapName.map1 != undefined do (
				if classof mapName.map1 != Bitmaptexture then (
					GetMaps mapName.map1
					) else (
						join mapFiles #( mapName.map1 )
						)
				)
			if mapName.map2 != undefined do (
				if classof mapName.map2 != Bitmaptexture then (
					GetMaps mapName.map2
					) else (
						join mapFiles #( mapName.map2 )
						)
				)	
			)	

		default: (
			if mapName != undefined do (
				join mapFiles #( mapName )
				propertyArray = #()
				propNames = getPropNames mapName
				
				for p = 1 to propNames.count do (
					try (
						property = getProperty mapName propNames[p] 
						if superclassof property == textureMap do (
							join propertyArray #( property )
							)
						) catch ()
					)
				for prop in propertyArray do GetMaps prop 
				)
			)
		)
)

fn GetBitmaps mtl = 
(
	mapArray = #()
	if superclassof mtl == textureMap then (
			GetMaps mtl
			join mapArray #( mapFiles )
			mapFiles = #()
		) else (
			for a = 1 to (getNumSubTexmaps mtl) do (
				if ( ( getSubTexmap mtl a ) != undefined ) do (
					mapName = ( getSubTexmap mtl a )
					GetMaps mapName
					join mapArray #( mapFiles )
					mapFiles = #()
					)
				)
			)
			
	for b = 1 to mapArray.count do (
		for c = 1 to mapArray[b].count do (
			join colMats #( colMatsSub= #( mapArray[b][c] ) )
			if classof mapArray[b][c] == bitmaptexture then (
				join colMatsSub #( "tex" )
				) else (
					join colMatsSub #( "map" )
					)
					if b > 1 then join colMatsSub #( " [" + getSubTexmapSlotName mtl b + "]" ) else join colMatsSub #( "" )
			)
		)
)

fn matlists mtl type = 
(
	local checkType = #( Blend, VRayBlendMtl, CompositeMaterial, doubleSided, MultiMaterial, Shellac, Shell_Material, TopBottom, VRay2SidedMtl )
	case classof mtl of (

		Blend: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)

			local blendMat = #()

			if (mtl.map1 != undefined ) do (
				if ( findItem checkType ( classof mtl.map1 ) > 0 ) then (
					matlists mtl.map1 "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.map1 ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.map1
						)
				)
			if ( mtl.map2 != undefined ) do (
				if ( findItem checkType ( classof mtl.map2 ) > 0 ) then (
					matlists mtl.map2 "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.map2 ) )
						join colMatsSub #( "sub" )
							
						GetBitmaps mtl.map2
						)
				)
			if ( mtl.mask != undefined ) do (
				GetBitmaps mtl.mask
				)
		)
		
		VRayBlendMtl: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)


			if ( mtl.baseMtl != undefined ) do (
				if ( findItem checkType ( classof mtl.baseMtl ) > 0 ) then (
					matlists mtl.baseMtl "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.baseMtl ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.baseMtl
						)
				)
			
				
			local m
			for m = 1 to mtl.coatMtl.count do (
				if ( mtl.coatMtl[m] != undefined ) do (
					if ( findItem checkType ( classof mtl.coatMtl[m] ) > 0 ) then (
						matlists mtl.coatMtl[m]  "sub"
						) else (
							join colMats  #( colMatsSub = #(mtl.coatMtl[m] ) )
							join colMatsSub #( "sub" )

							GetBitmaps mtl.coatMtl[m]
							)
					)
			)
			for m = 1 to mtl.texmap_blend.count do (
				if ( mtl.texmap_blend[m] != undefined ) do (
					if ( findItem checkType ( classof mtl.texmap_blend[m] ) > 0 ) then (
						matlists mtl.texmap_blend[m]  "sub"
						) else (
							join colMats  #( colMatsSub = #(mtl.texmap_blend[m] ) )
							join colMatsSub #( "sub" )

							GetBitmaps mtl.texmap_blend[m]
							)
					)
			)			
		)
		
		Shellac: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)

			if ( mtl.shellacMtl1 != undefined ) do (
				if ( findItem checkType ( classof mtl.shellacMtl1 ) > 0 ) then (
					matlists mtl.shellacMtl1 "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.shellacMtl1 ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.shellacMtl1
						)
				)
			if ( mtl.shellacMtl2 != undefined ) do (
				if ( findItem checkType ( classof mtl.shellacMtl2 ) > 0 ) then (
					matlists mtl.shellacMtl2 "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.shellacMtl2 ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.shellacMtl2
						)
				)
		)

		TopBottom: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)

			if ( mtl.topMaterial != undefined ) do (
				if ( findItem checkType ( classof mtl.topMaterial ) > 0 ) then (
					matlists mtl.topMaterial "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.topMaterial ) )
						join colMatsSub #( "sub" )	

						GetBitmaps mtl.topMaterial
						)
				)
			if ( mtl.bottomMaterial != undefined ) do (
				if ( findItem checkType ( classof mtl.bottomMaterial ) > 0 ) then (
					matlists mtl.bottomMaterial "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.bottomMaterial ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.bottomMaterial
						)
				)
		)

		doubleSided: (
			
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)

			if ( mtl.material1 != undefined ) do (
				if ( findItem checkType ( classof mtl.material1 ) > 0 ) then (
					matlists mtl.material1 "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.material1 ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.material1
						)
				)
			if ( mtl.material2 != undefined ) do (
				if ( findItem checkType ( classof mtl.material2 ) > 0 ) then (
					matlists mtl.material2 "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.material2 ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.material2	
						)
				)
		)

		VRay2SidedMtl: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)

			if ( mtl.frontMtl != undefined ) do (
				if ( findItem checkType ( classof mtl.frontMtl ) > 0 ) then (
					matlists mtl.frontMtl "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.frontMtl ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.frontMtl
						)
				)
			if ( mtl.backMtl != undefined ) do (
				if ( findItem checkType ( classof mtl.backMtl ) > 0 ) then (
					matlists mtl.backMtl "sub"
					) else (
						join colMats  #( colMatsSub = #( mtl.backMtl ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.backMtl	
						)
				)
			if ( mtl.texmap_translucency != undefined ) do (
				GetBitmaps mtl
				)	
		)

		Shell_Material: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)

			if ( mtl.originalMaterial != undefined ) do (
				if ( findItem checkType ( classof mtl.originalMaterial ) > 0 ) then (
					matlists mtl.originalMaterial "sub"
					) else (
						join colMats  #( colMatsSub = #(mtl.originalMaterial ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.originalMaterial
						)
				)
			if ( mtl.bakedMaterial != undefined ) do (
				if ( findItem checkType ( classof mtl.bakedMaterial ) > 0 ) then (
					matlists mtl.bakedMaterial "sub"
					) else (
						join colMats  #( colMatsSub = #(mtl.bakedMaterial ) )
						join colMatsSub #( "sub" )

						GetBitmaps mtl.bakedMaterial
						)
				)
		)

		MultiMaterial: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)

			local m
			for m = 1 to mtl.numsubs do (
				if ( mtl[m] != undefined ) do (
					if ( findItem checkType ( classof mtl[m] ) > 0 ) then (
						matlists mtl[m]  "sub"
						) else (
							join colMats  #( colMatsSub = #(mtl[m] ) )
							join colMatsSub #( "sub" )

							GetBitmaps mtl[m]
							)
					)
			)
		)

		CompositeMaterial: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)

			local c
			for c = 1 to mtl.materialList.count do (
				if ( mtl.materialList[c] != undefined ) do (
					if ( findItem checkType ( classof mtl.materialList[c] ) > 0 ) then (
						matlists mtl.materialList[c] "sub"
						) else (
							join colMats  #( colMatsSub = #( mtl.materialList[c] ) )
							join colMatsSub #( "sub" )

							GetBitmaps mtl.materialList[c]
							)
					)
			)
		)
		
		default: (
			if type == "sub" then (
				join colMats  #( colMatsSub = #( mtl ) )
				join colMatsSub #( "sub" )
				) else (
					join colMats  #( colMatsSub = #( mtl ) )
					join colMatsSub #( "mat" )
					)
					
			if ( superclassof mtl == material ) do (
				if ( getNumSubMtls mtl > 0 ) do (
					for d = 1 to getNumSubMtls mtl do (
						if ( getSubMtl mtl d ) != undefined do (
							matlists ( getSubMtl mtl d ) "sub"
							)
						)
					)
				)
			GetBitmaps mtl
		)
		
	)
)

fn CollectAllMaterials = 
(
	colMats = #()
	colMatsSub = #()
	mapFiles= #()
	
	allMats = #()
	for m in scenematerials do 
		matlists m "run"
	for arr in colMats do
		if (arr[2] == "sub" or arr[2] == "mat") then
			appendIfUnique allMats arr[1]
	
	
	--for m in allMats do print m.name
)

function CollectAllObject = 
(
	local list = $* as array
	/*
	for obj in geometry do
		appendIfUnique list obj
	for obj in lights do
		appendIfUnique list ob
	*/
	return list
)

fn isExistObjectName listObject newname =
(
	for obj in listObject do
		if (obj.name == newname) then
			return true
	return false
)

fn isExistTextureName listTexture newname =
(
	for obj in listTexture do
		if (obj[2] == newname) then
			return true
	return false
)

fn Export_FixMaterialName = 
(
	fn compMatNames name1 name2 = stricmp name1.name name2.name

	--- collect all material, sub and nest
	CollectAllMaterials()
	--for m in allMats do print m.name
		
	---fix weird name
	subMats = #()
	
	for m in allMats do
	(
		if (isHavingWeirdCharacter m.name) then
		(
				m.name = FixWeirdCharacter m.name
		)
		
	)
	--for m in allMats do print m.name
	--fix duplicate name
	qSort allMats compMatNames	
	if (allMats.count >= 2) then
	(
		local startName = allMats[1].name
		local c = 0
		for i=2 to allMats.count do
			if (startName == allMats[i].name) then
			(
				local newname =""
				local checking = true
				
				while (checking) do
				(
					c += 1
					newname =  "_" + int2String c "" 
					if (isExistObjectName allMats (allMats[i].name+newname)) then
						checking = true
					else
						checking = false
				)
				allMats[i].name = allMats[i].name +newname
			)
			else
			(
				startName = allMats[i].name
				c = 0
			)
		--for m in allMats do print m.name
	)
		
	---fix start with number
	for mat in allMats do
		if (isStartingWithNumber mat.name) then
		(
				mat.name = "mat_"+mat.name
		)		
	---fix same with object name
	local listObj = CollectAllObject()
	for mat in allMats do
		for obj in listObj do
			if (mat.name == obj.name) then
					mat.name = "mat_"+mat.name
)

fn Export_FixObjectName = 
(
	fn compObjNames name1 name2 = stricmp name1.name name2.name
	--collect all object name
	local listObj = CollectAllObject()
	qSort listObj compObjNames	
	--for obj in listObj do print obj.name
	
	
	---fix weird name
	for obj in listObj do
	(
		if (isHavingWeirdCharacter obj.name) then
		(
				obj.name = FixWeirdCharacter obj.name
		)
	)
	--for obj in listObj do print obj.name
		
	--fix duplicate name
	qSort listObj compObjNames	
	if (listObj.count >= 2) then
	(
		local startName = listObj[1].name
		local c = 0
		for i=2 to listObj.count do
			if (startName == listObj[i].name) then
			(
				local newname =""
				local checking = true
				while (checking) do
				(
					c += 1
					newname =   "_"+ int2String c ""
					if (isExistObjectName listObj (listObj[i].name+newname)) then
						checking = true
					else
						checking = false
				)
				listObj[i].name = listObj[i].name+newname
			)
			else
			(
				startName = listObj[i].name
				c = 0
			)	
		--for obj in listObj do print obj.name
		--for obj in selection do obj.name = "box"
		)
		---fix start with number
	for obj in listObj do
		if (isStartingWithNumber obj.name) then
		(
				obj.name = "obj_"+obj.name
		)

)

fn Export_FixTextureName = 
(
	fn compTexNames name1 name2 = stricmp name1[2] name2[2]
	--collect all texture name
	listTexture = #()
	for b in (getClassInstances BitmapTexture) do 
	try(
		local fullname = mapPaths.getFullFilePath b.filename
		local dup = false
		for file in listTexture do
			if (fullname == file[4]) then
			(
				--print ("king"+fullname)
				dup = true
			)
		if dup==false then append listTexture #(getFilenameFile b.filename,"",getFilenameType b.filename, fullname,fullname)
	) catch()
	qSort listTexture compTexNames
	---fix weird name
	for tex in listTexture do
	(
		if (isHavingWeirdCharacter tex[1]) then
		(
				tex[2] = FixWeirdCharacter tex[1]
		)
		else
			tex[2] = ""+tex[1]
	)
	--return ""
	--fix duplicate name
	qSort listTexture compTexNames		
	if (listTexture.count < 2) then
			return ""
	local startName = listTexture[1]
	local c = 0
	for i=2 to listTexture.count do
	(
		if (startName[2] == listTexture[i][2] and startName[3] == listTexture[i][3]) then
		(
			local newname =""
			local checking = true
			while (checking) do
			(
				c += 1
				newname =  "_"+ int2String c "" 
				if (isExistTextureName listTexture (listTexture[i][2]+newname)) then
					checking = true
				else
					checking = false
			)
			listTexture[i][2] = listTexture[i][2]+newname
		)
		else
		(
			startName =listTexture[i]
			c = 0
		)	
	)
	
	--copy to newname
	for tex in listTexture do
	(
		if (tex[1] != tex[2]) then
		(
			local newfilename = (getFilenamePath tex[4]) + tex[2] + tex[3]
			tex[5] = newfilename
			--deleteFile newfilename
			
			copyFile tex[4] newfilename
		)
	)
	
)
fn GatherTexturesToTexFolder =
(
	listTexture = #()
	for b in (getClassInstances BitmapTexture) do 
	(
		try(
			local fullname = mapPaths.getFullFilePath b.filename
			append listTexture #(b.filename, fullname)
-- 			print("-------------- b.filename = "+b.filename)
-- 			print("---------------- fullname = "+fullname)
		) catch()
	)
	print("userPath = "+userPath)
	texFolderPath = userPath+"\\tex\\"
	if not doesFileExist texFolderPath do makeDir texFolderPath
	for tex in listTexture do
	(
		newFullPath = texFolderPath + (filenameFromPath tex[2])
		print("new tex = "+newFullPath as string)
		copyFile tex[2] newFullPath
	)
)

function isVray mat = 
(
	local isVray = false
	local s = tolower (mat as string)
	if (findString s "vray" != undefined) then
		isVray = true
	return isVray
)

function checkWeirdName =
(
	fn compObjNames name1 name2 = stricmp name1.name name2.name
	local val = false
	for b in (getClassInstances BitmapTexture) do 
	try
	(
		local filename = getFilenameFile b.filename
		 if (isHavingWeirdCharacter filename) then
			return true
	)catch()
	 
	----------------object-----------------------------
	local listObj = collectAllObject()
	qSort listObj compObjNames	
	--object: weird name
	for i=1 to listObj.count do
	(
		 if (isHavingWeirdCharacter listObj[i].name) then
			return true
		if (isStartingWithNumber listObj[i].name) then
			return true
	)
	--object: duplicate name
	for i=1 to listObj.count-1 do
		 if (listObj[i].name == listObj[i+1].name) then
			return true
	
	----------------material-----------------------------
	CollectAllMaterials()
	qSort allMats compObjNames
	--mat: weird name
	for m in allMats do
	(
		try(
			 if (isHavingWeirdCharacter m.name) then
				return true
		) catch()
		try(
			if (isStartingWithNumber m.name) then
				return true
		) catch()
	)
	for i=1 to allMats.count-1 do
	--mat: duplicate name
	try(			
		 if (allMats[i].name == allMats[i+1].name) then
			return true
	) catch()
	--mat name vs obj name
	for m in allMats do
		for obj in listObj do
		try(			
			 if (m.name == obj.name) then
				return true
		) catch()
			
	return false
)

function fbxtext2Hex s =
(
	local ch = "abcdefghijklmnopqrstuvwxyz123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local hex = ""
	for i=1 to s.count do
		if (findString ch s[i] == undefined) then
			hex += "FBXASC0"+(bit.charAsInt s[i]) as string
		else
			hex += s[i]	
	return hex
)

function replacestring s t t1=
(
	local pos = 1
	local i = 0
	while (pos != undefined and i<100) do
	(
		i += 1
		pos = findstring s t
		if (pos != undefined) then
		(
			s = replace s pos t.count t1

		)
	)
	return s
)

function color2String c =
(
	local temp = ((mathlib.round c.red) as string +" "+(mathlib.round c.green) as string+" "+(mathlib.round c.blue) as string)
	return replacestring temp ".0d0" ""
)

function zipToFilename filename =
(
	if isZip then
		return (getFilenameFile filename +  getFilenameType filename)
	else
		return filename
)
function getAbsolutePath filename =
(
	if (filename != undefined) then
	(
		local val = mapPaths.getFullFilePath filename
		if (val != "") then
		(
			for tex in listTexture do
				if (val == tex[4]) then
					val = tex[5]
			return (zipToFilename val)
		)
		else 
			return (zipToFilename filename)
	)
)

function object2Element objEle obj=
(
	if (classof obj == StandardTextureOutput) then
	(
		objEle.SetAttribute "output_invert" (obj.invert as string)
		objEle.SetAttribute "output_clamp" (obj.clamp as string)
		objEle.SetAttribute "output_alphaFromRGB" (obj.alphaFromRGB as string)
		objEle.SetAttribute "output_rgb_level" (obj.rgb_level as string)
		objEle.SetAttribute "output_rgb_offset" (obj.rgb_offset as string)
		objEle.SetAttribute "output_amount" (obj.output_amount as string)
		objEle.SetAttribute "output_bump_amount" (obj.bump_amount as string)
	)		
)
function param2Elenment subParam subname=
(
		local subele = xml.CreateElement "param"
		subele.SetAttribute "paramName" subname
		subele.SetAttribute "type" ((classof subParam) as string)
		if (classof subParam == StandardUVGen) then
		(

			subele.SetAttribute "coord_blur" (subParam.blur as string)
			if (subParam.mappingType == 0) then
			(
				subele.SetAttribute "coord_mapping" (#("Explicit Map Channel","Vertex Color Channel","Planar from Object XYZ","Planar from World XYZ")[subParam.mapping+1])
				subele.SetAttribute "coord_mappingType" "Texture"
			)
			else
			(
				subele.SetAttribute "coord_mapping" (#("Spearical Environment","Cylindrical Environment","Shrink-wrap Environment","Screen")[subParam.mapping+1])
				subele.SetAttribute "coord_mappingType" "Environ"
			)


			subele.SetAttribute "coord_mapChannel" (subParam.mapChannel as string)
			subele.SetAttribute "coord_UVW_Type" (subParam.UVW_Type as string)
			subele.SetAttribute "coord_U_Mirror" (subParam.U_Mirror as string)
			subele.SetAttribute "coord_V_Mirror" (subParam.V_Mirror as string)
			subele.SetAttribute "coord_U_Tile" (subParam.U_Tile as string)
			subele.SetAttribute "coord_V_Tile" (subParam.V_Tile as string)
			subele.SetAttribute "coord_showMapOnBack" (subParam.showMapOnBack as string)
			subele.SetAttribute "coord_Noise_On" (subParam.Noise_On as string)
			subele.SetAttribute "coord_Noise_Animate" (subParam.Noise_Animate as string)
			subele.SetAttribute "coord_UVTransform" (subParam.UVTransform as string)
			subele.SetAttribute "coord_realWorldScale" (subParam.realWorldScale as string)
			subele.SetAttribute "coord_realWorldHeight" (subParam.realWorldHeight as string)
			subele.SetAttribute "coord_realWorldWidth" (subParam.realWorldWidth as string)
			
		
			subele.SetAttribute "coord_phase" (subParam.phase  as string)
			subele.SetAttribute "coord_U_Offset" (subParam.U_Offset as string)
			subele.SetAttribute "coord_V_Offset" (subParam.V_Offset as string)
			subele.SetAttribute "coord_U_Tiling" (subParam.U_Tiling as string)
			subele.SetAttribute "coord_V_Tiling" (subParam.V_Tiling as string)
			subele.SetAttribute "coord_U_angle" (subParam.U_angle as string)
			subele.SetAttribute "coord_V_angle" (subParam.V_angle as string)
			
			subele.SetAttribute "coord_W_angle" (subParam.W_angle as string)
			subele.SetAttribute "coord_Noise_Amount" (subParam.Noise_Amount as string)
			subele.SetAttribute "coord_Noise_Size" (subParam.Noise_Size as string)
			subele.SetAttribute "coord_Noise_Levels" (subParam.Noise_Levels as string)
			subele.SetAttribute "coord_blur_Offset" (subParam.blur_Offset as string)
			
		)
		if (classof subParam == StandardTextureOutput) then
		(
			subele.SetAttribute "output_invert" (subParam.invert as string)
			subele.SetAttribute "output_clamp" (subParam.clamp as string)
			subele.SetAttribute "output_alphaFromRGB" (subParam.alphaFromRGB as string)
			subele.SetAttribute "output_rgb_level" (subParam.rgb_level as string)
			subele.SetAttribute "output_rgb_offset" (subParam.rgb_offset as string)
			subele.SetAttribute "output_amount" (subParam.output_amount as string)
			subele.SetAttribute "output_bump_amount" (subParam.bump_amount as string)
		)
		return subele
)
function shader2Element subShader subname=
(
	if (subShader == undefined) then
	(
		return undefined
	)
	else
	(
		if (subname == "diffuse_map") then
		(
			try(
				local dele = xml.CreateElement "map"
				dele.SetAttribute "filename" (getAbsolutePath subShader.filename)
				root04.appendChild dele
			) catch()
		)
		local subele = xml.CreateElement "shader"
		subele.SetAttribute "shaderName" subname
		subele.SetAttribute "type" ((classof subShader) as string)
		try
		(
			subele.SetAttribute "name" subShader.name
			subele.SetAttribute "fbxname" (fbxtext2Hex subShader.name)
		)
		catch()
		
		if (classof subShader == Bitmaptexture) then
		(
			try(
				subele.SetAttribute "filename" (getAbsolutePath subShader.filename)
			) catch()
			try (subele.appendChild  (param2Elenment subShader.output "Output")	) catch ()
			try (	subele.appendChild  (param2Elenment subShader.Coordinates "Coordinates")	) catch ()
		)
		if (classof subShader == Output) then
		(
			subele.SetAttribute "output_map1Enabled" (subShader.map1Enabled as string)
			try (
				subele.appendChild  (shader2Element subShader.map1 "output_map")
			) catch ()						
			try (
				subele.appendChild  (param2Elenment subShader.output "output_textureOutput")
			) catch ()						
			--object2Element subele subShader.output
		)
		if (classof subShader == VRayNormalMap) then
		(
			try (subele.appendChild  (shader2Element subShader.normal_map "vraynormalmap_normal_map")	) catch ()
		)
		if (classof subShader == Normal_Bump) then
		(
			subele.SetAttribute "normal_mult_spin" (subShader.mult_spin as string)
			subele.SetAttribute "normal_bump_spin" (subShader.bump_spin as string)
			subele.SetAttribute "normal_map1on" (subShader.map1on as string)
			subele.SetAttribute "normal_map2on" (subShader.map2on as string)
			subele.SetAttribute "normal_method" (#("Tangent","Local XYZ","Screen","World")[subShader.method+1])
			subele.SetAttribute "normal_flipred" (subShader.flipred as string)
			subele.SetAttribute "normal_flipgreen" (subShader.flipgreen as string)
			subele.SetAttribute "normal_swap_rg" (subShader.swap_rg as string)
			try (subele.appendChild  (shader2Element subShader.normal_map "normal_normal_map")	) catch ()						
			try (subele.appendChild  (shader2Element subShader.bump_map "normal_bump_map")) catch ()	
		)
		if (classof subShader == Speckle) then
		(
			subele.SetAttribute "speckle_size" (subShader.size as string)
			subele.SetAttribute "speckle_color1" (color2String subShader.color1)
			subele.SetAttribute "speckle_color2" (color2String subShader.color2)
			subele.SetAttribute "speckle_map1on" (subShader.map1on as string)
			subele.SetAttribute "speckle_map2on" (subShader.map2on as string)
			try (subele.appendChild  (shader2Element subShader.MAP1 "speckle_map1") ) catch ()						
			try (subele.appendChild  (shader2Element subShader.MAP2 "speckle_map2") ) catch ()	
		)	
		if (classof subShader == RGB_Tint) then
		(
			subele.SetAttribute "tint_map1Enabled" (subShader.map1Enabled as string)
			subele.SetAttribute "tint_red" (color2String  subShader.red)				
			subele.SetAttribute "tint_green" (color2String  subShader.green)				
			subele.SetAttribute "tint_blue" (color2String  subShader.blue)				
			try (	subele.appendChild  (shader2Element subShader.map1 "tint_map")) catch ()						
		)
		if (classof subShader == VRayColor) then
		(
			numstring = floor(subShader.red*255) as string
			stringsplit = FilterString numstring "."
			colorstring1 = stringsplit[1]
			numstring = floor(subShader.green*255) as string
			stringsplit = FilterString numstring "."
			colorstring2 = stringsplit[1]
			numstring = floor(subShader.blue*255) as string
			stringsplit = FilterString numstring "."
			colorstring3 = stringsplit[1]
			subele.SetAttribute "vrcolor_color" (colorstring1+" "+colorstring2+" "+colorstring3)
		)	
		if (classof subShader == Gradient_Ramp) then
		(
			subele.SetAttribute "ramp_size" (subShader.size as string)
			subele.SetAttribute "ramp_phase" (subShader.phase as string)
			subele.SetAttribute "ramp_amount" (subShader.amount as string)
			subele.SetAttribute "ramp_levels" (subShader.levels as string)
			subele.SetAttribute "ramp_gradientType" (#("4 Corner","Box","Diagonal","Lighting","Linear","Mapped","Normal","Pong","Radial","Spiral","Sweep","Tartan")[subShader.Gradient_Type+1])
			subele.SetAttribute "ramp_noiseType" (#("Regular","Fractal","Turbulence")[subShader.Noise_Type+1])
			subele.SetAttribute "ramp_lowThreshold" (subShader.Low_Threshold as string)
			subele.SetAttribute "ramp_highThreshold" (subShader.High_Threshold as string)
			subele.SetAttribute "ramp_thresholdSmoothing" (subShader.Threshold_Smoothing as string)
			subele.SetAttribute "ramp_sourceMapOn" (subShader.Source_Map_On as string)
			try (subele.SetAttribute "ramp_Flag_Color1" (subShader.Gradient_Ramp.Flag__1.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color1_pos" (subShader.Gradient_Ramp.Flag__1.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color2" (subShader.Gradient_Ramp.Flag__2.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color2_pos" (subShader.Gradient_Ramp.Flag__2.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color3" (subShader.Gradient_Ramp.Flag__3.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color3_pos" (subShader.Gradient_Ramp.Flag__3.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color4" (subShader.Gradient_Ramp.Flag__4.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color4_pos" (subShader.Gradient_Ramp.Flag__4.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color5" (subShader.Gradient_Ramp.Flag__5.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color5_pos" (subShader.Gradient_Ramp.Flag__5.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color6" (subShader.Gradient_Ramp.Flag__6.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color6_pos" (subShader.Gradient_Ramp.Flag__6.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color7" (subShader.Gradient_Ramp.Flag__7.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color7_pos" (subShader.Gradient_Ramp.Flag__7.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color8" (subShader.Gradient_Ramp.Flag__8.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color8_pos" (subShader.Gradient_Ramp.Flag__8.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color9" (subShader.Gradient_Ramp.Flag__9.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color9_pos" (subShader.Gradient_Ramp.Flag__9.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color10" (subShader.Gradient_Ramp.Flag__10.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color10_pos" (subShader.Gradient_Ramp.Flag__10.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color11" (subShader.Gradient_Ramp.Flag__11.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color11_pos" (subShader.Gradient_Ramp.Flag__11.position as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color12" (subShader.Gradient_Ramp.Flag__12.color as string)) catch()
			try (subele.SetAttribute "ramp_Flag_Color12_pos" (subShader.Gradient_Ramp.Flag__12.position as string)) catch()
			try (subele.appendChild  (param2Elenment subShader.output "Output")	) catch ()						
			try (	subele.appendChild  (param2Elenment subShader.Coordinates "Coordinates")	) catch ()						
				
		)
		if (classof subShader == Gradient) then
		(
			subele.SetAttribute "color1" (color2String  subShader.color1)				
			subele.SetAttribute "color2" (color2String  subShader.color2)				
			subele.SetAttribute "color3" (color2String  subShader.color3)				
			subele.SetAttribute "map1Enabled" (subShader.map1Enabled as string)
			subele.SetAttribute "map2Enabled" (subShader.map2Enabled as string)
			subele.SetAttribute "map3Enabled" (subShader.map3Enabled as string)
			try (	subele.appendChild  (shader2Element subShader.map1 "map1")) catch ()						
			try (	subele.appendChild  (shader2Element subShader.map2 "map2")) catch ()						
			try (	subele.appendChild  (shader2Element subShader.map3 "map3")) catch ()						
			subele.SetAttribute "color2Pos" (subShader.color2Pos as string)
			subele.SetAttribute "gradientType" (#("Linear","Radial")[subShader.gradientType+1])
			subele.SetAttribute "noiseAmount" (subShader.noiseAmount as string)
			subele.SetAttribute "noiseType" (#("Regular","Fractal","Turbulence")[subShader.noiseType+1])
			subele.SetAttribute "noiseSize" (subShader.noiseSize as string)
			subele.SetAttribute "noisePhase" (subShader.noisePhase as string)
			subele.SetAttribute "noiseLevels" (subShader.noiseLevels as string)
			subele.SetAttribute "noiseThresholdLow" (subShader.noiseThresholdLow as string)
			subele.SetAttribute "noiseThresholdHigh" (subShader.noiseThresholdHigh as string)
			subele.SetAttribute "noiseThresholdSMooth" (subShader.noiseThresholdSMooth as string)
			try (subele.appendChild  (param2Elenment subShader.output "Output")	) catch ()						
			try (	subele.appendChild  (param2Elenment subShader.Coordinates "Coordinates")	) catch ()						
		)
		if (classof subShader == Color_Correction) then
		(
			local rewriteMode = #("Red","Green","Blue","Alpha","Red (Inverse)","Green (Inverse)","Blue (Inverse)","Alpha (Inverse)","Monochrome","One","Zero")
			subele.SetAttribute "cc_Color" (color2String  subShader.color)				
			subele.SetAttribute "cc_rewriteMode" (#("Normal","Monochrome","Invert","Custom")[subShader.rewireMode+1])
			subele.SetAttribute "cc_rewriteR" (rewriteMode[subShader.rewireR+1])
			subele.SetAttribute "cc_rewriteG" (rewriteMode[subShader.rewireG+1])
			subele.SetAttribute "cc_rewriteB" (rewriteMode[subShader.rewireB+1])
			subele.SetAttribute "cc_rewriteA" (rewriteMode[subShader.rewireA+1])
			subele.SetAttribute "cc_hueShift" (subShader.hueShift as string)
			subele.SetAttribute "cc_saturation" (subShader.saturation as string)
			subele.SetAttribute "cc_tint" (color2String  subShader.tint)				
			subele.SetAttribute "cc_tintStrength" (subShader.tintStrength as string)
			subele.SetAttribute "cc_lightnessMode" (#("Standard","Advanced")[subShader.lightnessMode+1])
			if subShader.lightnessMode==0 then (
				subele.SetAttribute "cc_contrast" (subShader.contrast as string)
				subele.SetAttribute "cc_brightness" (subShader.brightness as string)
			)
			subele.SetAttribute "cc_exposureMode" (#("Gain","F-stops","Printer Lights")[subShader.exposureMode+1])
			subele.SetAttribute "cc_enableR" (subShader.enableR as string)				
			subele.SetAttribute "cc_enableG" (subShader.enableG as string)				
			subele.SetAttribute "cc_enableB" (subShader.enableB as string)				
			subele.SetAttribute "cc_gainRGB" (subShader.gainRGB as string)				
			subele.SetAttribute "cc_gainR" (subShader.gainR as string)				
			subele.SetAttribute "cc_gainG" (subShader.gainG as string)				
			subele.SetAttribute "cc_gainB" (subShader.gainB as string)				
			subele.SetAttribute "cc_gammaRGB" (subShader.gammaRGB as string)				
			subele.SetAttribute "cc_gammaR" (subShader.gammaR as string)				
			subele.SetAttribute "cc_gammaG" (subShader.gammaG as string)				
			subele.SetAttribute "cc_gammaB" (subShader.gammaB as string)				
			subele.SetAttribute "cc_pivotR" (subShader.pivotR as string)				
			subele.SetAttribute "cc_pivotG" (subShader.pivotG as string)				
			subele.SetAttribute "cc_pivotB" (subShader.pivotB as string)				
			subele.SetAttribute "cc_liftRGB" (subShader.liftRGB as string)				
			subele.SetAttribute "cc_liftR" (subShader.liftR as string)				
			subele.SetAttribute "cc_liftG" (subShader.liftG as string)				
			subele.SetAttribute "cc_liftB" (subShader.liftB as string)				
			subele.SetAttribute "cc_printerLights" (subShader.printerLights as string)				
			
			try (
				subele.appendChild  (shader2Element subShader.map "cc_map")
			) catch ()	
		)
		if (classof subShader == CompositeTexturemap) then
		(
			for i=1 to  subShader.mapEnabled.count do
			(
				subele.SetAttribute ("composite_mapEnabled"+i as string) (subShader.mapEnabled[i] as string)
				subele.SetAttribute ("composite_maskEnabled"+i as string) (subShader.maskEnabled[i] as string)
				subele.SetAttribute ("composite_blendMode"+i as string) (#("Normal","Average","Addition","Subtract","Darken","Multiply","Color Burn","Linear Burn","Lighten","Screen","Color Dodge","Linear Dodge","Spotlight","Spotlight Blend","Overlay","Soft Light","Hard light","Pin Light","Hard Mix","Difference","Exclusion","Hue","Saturation","Value")[subShader.blendMode[i]+1])
				subele.SetAttribute ("composite_layerName"+i as string) (subShader.layerName[i] as string)
				subele.SetAttribute ("composite_dlgOpened"+i as string) (subShader.dlgOpened[i] as string)
				subele.SetAttribute ("composite_opacity"+i as string) (subShader.opacity[i] as string)

				try (	subele.appendChild  (shader2Element subShader.mapList[i] ("composite_map"+i as string))) catch (print("Naw"))		
				
				try (	subele.appendChild  (shader2Element subShader.mask[i] ("composite_mask"+i as string))	) catch (print("Naw"))
			)
			
		)			
		if (classof subShader == Mix) then
		(
			subele.SetAttribute "mix_mixAmount" (subShader.mixAmount as string)
			subele.SetAttribute "mix_lower" (subShader.lower as string)
			subele.SetAttribute "mix_upper" (subShader.upper as string)
			subele.SetAttribute "mix_color1" (color2String  subShader.color1)
			subele.SetAttribute "mix_color2" (color2String  subShader.color2)
			subele.SetAttribute "mix_map1Enabled" (subShader.map1Enabled as string)
			subele.SetAttribute "mix_map2Enabled" (subShader.map2Enabled as string)
			subele.SetAttribute "mix_maskEnabled" (subShader.maskEnabled as string)
			subele.SetAttribute "mix_useCurve" (subShader.useCurve as string)
			try (	subele.appendChild  (shader2Element subShader.map1 "mix_map1")) catch ()				
			try (	subele.appendChild  (shader2Element subShader.map2 "mix_map2")) catch ()				
			try (	subele.appendChild  (shader2Element subShader.mask "mix_mask")) catch ()				
			
		)
		if (classof subShader == Cellular) then
		(
			subele.SetAttribute "cell_Color" (color2String  subShader.cellColor)
			subele.SetAttribute "cell_map1Enabled" (subShader.map1Enabled as string)
			try ( subele.appendChild (shader2Element subShader.cellMap "cell_map" ) ) catch()		
			subele.SetAttribute "cell_divColor1" (color2String  subShader.divColor1)
			subele.SetAttribute "cell_map1Enabled" (subShader.map2Enabled as string)
			try ( subele.appendChild (shader2Element subShader.divMap1 "cell_divMap1" ) ) catch()	
			subele.SetAttribute "cell_divColor2" (color2String  subShader.divColor2)
			subele.SetAttribute "cell_map2Enabled" (subShader.map3Enabled as string)
			try ( subele.appendChild (shader2Element subShader.divMap2 "cell_divMap2" ) ) catch()					
			subele.SetAttribute "cell_type" #("Circular","Chips")[subShader.type+1]
			subele.SetAttribute "cell_size" (subShader.size as string)
			subele.SetAttribute "cell_spread" (subShader.spread as string)
			subele.SetAttribute "cell_fractal" (subShader.fractal as string)
			subele.SetAttribute "cell_iteration" (subShader.iteration as string)
			subele.SetAttribute "cell_adaptive" (subShader.adaptive as string)
			subele.SetAttribute "cell_roughness" (subShader.roughness as string)
			subele.SetAttribute "cell_lowThreshold" (subShader.lowThresh as string)
			subele.SetAttribute "cell_midthreshold" (subShader.midThresh as string)
			subele.SetAttribute "cell_highThreshold" (subShader.highThresh as string)
		)
		if (classof subShader == FallOff) then
		(
			subele.SetAttribute "falloffcolor1" (color2String  subShader.color1)
			subele.SetAttribute "falloffcolor2" (color2String  subShader.color2)
			subele.SetAttribute "falloff_map1Enable" (subShader.map1On as string)
			subele.SetAttribute "falloff_map1Amount" (subShader.map1Amount as string)
			try (	subele.appendChild  (shader2Element subShader.map1 "falloff_map1")) catch ()
			subele.SetAttribute "falloff_map2Enable" (subShader.map2On as string)
			subele.SetAttribute "falloff_map2Amount" (subShader.map2Amount as string)
			try (	subele.appendChild  (shader2Element subShader.map2 "falloff_map2")) catch ()
			subele.SetAttribute "fallof_type" #("Towards/Away","Perpendicular/Parallel","Fresnel","Shadow/Light","Distance Blend")[subShader.type+1]
			subele.SetAttribute "falloff_direction" #("Viewing Direction (Camera Z-Axis)","Camera X-Axis","Camera Y-Axis","Object","Local X-Axis","Local Y-Axis","Local Z-Axis","World X-Axis","World Y-Axis","World Z-Axis")[subShader.direction+1]
			subele.SetAttribute "falloff_nearDistance" (subShader.nearDistance as string)
			subele.SetAttribute "falloff_farDistance" (subShader.farDistance as string)
			subele.SetAttribute "falloff_extrapolate" (subShader.extrapolateOn as string)
			subele.SetAttribute "falloff_mtlIOROverride" (subShader.mtlIOROverride as string)
			subele.SetAttribute "falloff_ior" (subShader.ior as string)
		)
		if (classof subShader == VrayDirt) then
		(
			subele.SetAttribute "vrdirt_radius" (subShader.radius as string)
			subele.SetAttribute "vrdirt_occludedColor" (color2String  subShader.occluded_color)
			subele.SetAttribute "vrdirt_unoccludedColor" (color2String  subShader.unoccluded_color)
			subele.SetAttribute "vrdirt_distribution" (subShader.distribution as string)
			subele.SetAttribute "vrdirt_falloff" (subShader.falloff as string)
			subele.SetAttribute "vrdirt_subdivs" (subShader.subdivs as string)
			subele.SetAttribute "vrdirt_bias" (subShader.bias as string)
			
			subele.SetAttribute "vrdirt_affectAlpha" (subShader.affect_alpha as string)
			subele.SetAttribute "vrdirt_ignoreForGI" (subShader.ignore_for_gi as string)
			subele.SetAttribute "vrdirt_considerSameObjectOnly" (subShader.consider_same_object_only as string)
			subele.SetAttribute "vrdirt_invertNormal" (subShader.invert_normal as string)
			subele.SetAttribute "vrdirt_workWithTransparency" (subShader.work_with_transparency as string)
			subele.SetAttribute "vrdirt_environmentOcclusion" (subShader.environment_occlusion as string)
			subele.SetAttribute "vrdirt_mode" #("Ambient occlusion","Reflection occlusion (Phong)","Reflection occlusion (Blinn)","Reflection occlusion (Ward)")[subShader.mode+1]
			subele.SetAttribute "vrdirt_reflectionGlossiness" (subShader.reflection_glossiness as string)
			subele.SetAttribute "vrdirt_affectReflectionElements" (subShader.affect_reflection_elements as string)
			
			subele.SetAttribute "vrdirt_texmap_radius_multiplier" (subShader.texmap_radius_multiplier as string)
			subele.SetAttribute "vrdirt_texmap_radius_on" (subShader.texmap_radius_on as string)
			try ( subele.appendChild (shader2Element subShader.texmap_radius "vrdirt_texmap_radius" ) ) catch()
			
			subele.SetAttribute "vrdirt_texmap_occluded_color_multiplier" (subShader.texmap_occluded_color_multiplier as string)
			subele.SetAttribute "vrdirt_texmap_occluded_color_on" (subShader.texmap_occluded_color_on as string)
			try ( subele.appendChild (shader2Element subShader.texmap_occluded_color "vrdirt_occluded_color" ) ) catch()
			
			subele.SetAttribute "vrdirt_texmap_unoccluded_color_multiplier" (subShader.texmap_unoccluded_color_multiplier as string)
			subele.SetAttribute "vrdirt_texmap_unoccluded_color_on" (subShader.texmap_unoccluded_color_on as string)
			try ( subele.appendChild (shader2Element subShader.texmap_unoccluded_color "vrdirt_unoccluded_color" ) ) catch()
			
			subele.SetAttribute "vrdirt_texmap_reflection_glossiness_multiplier" (subShader.texmap_reflection_glossiness_mult as string)
			subele.SetAttribute "vrdirt_texmap_reflection_glossiness_on" (subShader.texmap_reflection_glossiness_on as string)
			try ( subele.appendChild (shader2Element subShader.texmap_reflection_glossiness "vrdirt_reflection_glossiness" ) ) catch()
			
		)
		if (classof subShader == Noise) then
		(
			subele.SetAttribute "noisecolor1" (color2String  subShader.color1)
			subele.SetAttribute "noisecolor2" (color2String  subShader.color2)
			subele.SetAttribute "noise_map1Enable" (subShader.map1Enabled as string)
			try ( subele.appendChild (shader2Element subShader.map1 "noise_map1" ) ) catch()	
				
			subele.SetAttribute "noise_map2Enable" (subShader.map2Enabled as string)
			try ( subele.appendChild (shader2Element subShader.map2 "noise_map2" ) ) catch()	
				
			subele.SetAttribute "noise_type" #("Regualr","Fractal","Turbulence")[subShader.type+1]
			subele.SetAttribute "noise_size" (subShader.size as string)
			subele.SetAttribute "noise_lowThreshold" (subShader.thresholdLow as string)
			subele.SetAttribute "noise_highThreshold" (subShader.thresholdHigh as string)
			subele.SetAttribute "noise_levels" (subShader.levels as string)
			subele.SetAttribute "noise_phase" (subShader.phase as string)
		)
		if (classof subShader == VrayMap) then
		(
			subele.SetAttribute "vrrefraf_refraf" (subShader.type as string)
			
			subele.SetAttribute "vrrefraf_reflglossyon" (subShader.reflect_glossy as string)
			subele.SetAttribute "vrrefraf_reflglossy" (subShader.reflect_glossiness as string)
			subele.SetAttribute "vrrefraf_reflcolor" (color2String subShader.reflect_color)
			try ( subele.appendChild (shader2Element subShader.reflect_filterMap "vrrefraf_reflmap" ) ) catch()
			subele.SetAttribute "vrrefraf_reflmapon" (subShader.reflect_filterMapOn as string)
			
			subele.SetAttribute "vrrefraf_refrglossyon" (subShader.refract_glossy as string)
			subele.SetAttribute "vrrefraf_refrglossy" (subShader.refract_glossiness as string)
			subele.SetAttribute "vrrefraf_refrcolor" (color2String subShader.refract_color)
			try ( subele.appendChild (shader2Element subShader.refract_filterMap "vrrefraf_refrmap" ) ) catch()
			subele.SetAttribute "vrrefraf_refrmapon" (subShader.refract_filterMapOn as string)
		)
		if (classof subShader == VRayHDRI) then
		(
			subele.SetAttribute "HDRIMapName" (getAbsolutePath (subShader.HDRIMapName as string))
			
			subele.SetAttribute "mapType" (#("Angular","Cubic","Spherical","Mirrored ball","3ds Max standard")[subShader.mapType+1])
			subele.SetAttribute "multiplier" (subShader.multiplier as string)
			subele.SetAttribute "renderMultiplier" (subShader.renderMultiplier as string)
			subele.SetAttribute "horizontalRotation" (subShader.horizontalRotation as string)
			subele.SetAttribute "verticalRotation" (subShader.verticalRotation as string)
			subele.SetAttribute "horizontalFlip" (subShader.horizontalFlip as string)
			subele.SetAttribute "verticalFlip" (subShader.verticalFlip as string)
			subele.SetAttribute "ground_on" (subShader.ground_on as string)
			subele.SetAttribute "ground_position" (subShader.ground_position as string)
			subele.SetAttribute "mapChannel" (subShader.mapChannel as string)
			subele.SetAttribute "gamma" (subShader.gamma as string)
			subele.SetAttribute "color_space" (subShader.color_space as string)
			subele.SetAttribute "interpType" (#("Bilinear","Bicubic","Biquadratic","Default")[subShader.interpType+1])
			subele.SetAttribute "cropplace_on" (subShader.cropplace_on as string)
			subele.SetAttribute "cropplace_mode" (subShader.cropplace_mode as string)
			subele.SetAttribute "cropplace_u" (subShader.cropplace_v as string)
			subele.SetAttribute "cropplace_v" (subShader.cropplace_v as string)
			subele.SetAttribute "cropplace_width" (subShader.cropplace_width as string)
			subele.SetAttribute "cropplace_height" (subShader.cropplace_height as string)
			subele.SetAttribute "rgbOutput" (subShader.rgbOutput as string)
			subele.SetAttribute "monoOutput" (subShader.monoOutput as string)
			subele.SetAttribute "alphaSource" (subShader.alphaSource as string)
			subele.SetAttribute "hdri_memLimit" (subShader.hdri_memLimit as string)
			subele.SetAttribute "clear_memory" (subShader.clear_memory as string)
			subele.SetAttribute "iflStartFrame" (subShader.iflStartFrame as string)
			subele.SetAttribute "iflEndCondition" (subShader.iflEndCondition as string)
			subele.SetAttribute "iflPlaybackRate" (subShader.iflPlaybackRate as string)
			try (subele.appendChild  (param2Elenment subShader.UVGen "UVGen")	) catch ()						
			try (subele.appendChild  (param2Elenment subShader.output "Output")	) catch ()						
			
		)
		return subele
	)
)
function mat2Element mat =
(
	local m = mat
	if (classof m == VRayBlendMtl) then
	(
		local ele = xml.CreateElement "blendmaterial"
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)
		ele.SetAttribute "vray"  "true"
		ele.SetAttribute "additiveMode" (m.additiveMode as string)
		ele.SetAttribute "matType" "VRayBlendMtl"
		
		if (m.basemtl != undefined) then
		(
				if (classof m.basemtl == Multimaterial) then
				try( 
					ele.SetAttribute "base_material"  m.basemtl[1].name
					root1.appendChild (mat2Element m.basemtl[1]) 
				) catch ()				
				else
				try( 
					ele.SetAttribute "base_material"  m.basemtl.name
					root1.appendChild (mat2Element m.basemtl) 
				) catch ()				
		)
		-----
		if (m.coatMtl_0 != undefined) then
		(
			ele.SetAttribute "coatMaterial0"  (m.coatMtl_0.name as string)
			ele.SetAttribute "fbxcoatMaterial0"  (fbxtext2Hex (m.coatMtl_0.name as string))
			ele.SetAttribute "color_blend0"  (color2String m.blend[1])
			try( root1.appendChild (mat2Element m.coatMtl_0) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_0 "coatShader0") ) catch ()	
			ele.SetAttribute "texturemap_blend_mult0"  (m.texmap_blend_mult_0 as string)
		)
		----
		if (m.coatMtl_1 != undefined) then
		(
			ele.SetAttribute "coatMaterial1"  (m.coatMtl_1.name as string)
			ele.SetAttribute "fbxcoatMaterial1"  (fbxtext2Hex (m.coatMtl_1.name as string))
			ele.SetAttribute "color_blend1"  (color2String m.blend[2])
			try( root1.appendChild (mat2Element m.coatMtl_1) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_1 "coatShader1") ) catch ()
			ele.SetAttribute "texturemap_blend_mult1"  (m.texmap_blend_mult_1 as string)
		)
		----
		if (m.coatMtl_2 != undefined) then
		(
			ele.SetAttribute "coatMaterial2"  (m.coatMtl_2.name as string)
			ele.SetAttribute "fbxcoatMaterial2"  (fbxtext2Hex (m.coatMtl_2.name as string))
			ele.SetAttribute "color_blend2"  (color2String m.blend[3])
			try( root1.appendChild (mat2Element m.coatMtl_2) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_2 "coatShader2")  ) catch ()
				
			ele.SetAttribute "texturemap_blend_mult2"  (m.texmap_blend_mult_2 as string)
		)
		----
		if (m.coatMtl_3 != undefined) then
		(						
			ele.SetAttribute "coatMaterial3"  (m.coatMtl_3.name as string)
			ele.SetAttribute "fbxcoatMaterial3"  (fbxtext2Hex (m.coatMtl_3.name as string))
			ele.SetAttribute "color_blend3"  (color2String m.blend[4])
			try( root1.appendChild (mat2Element m.coatMtl_3) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_3 "coatShader3")  ) catch ()
			ele.SetAttribute "texturemap_blend_mult3"  (m.texmap_blend_mult_3 as string)
		)
		----
		if (m.coatMtl_4 != undefined) then
		(						
			
			ele.SetAttribute "coatMaterial4"  (m.coatMtl_4.name as string)
			ele.SetAttribute "fbxcoatMaterial4"  (fbxtext2Hex (m.coatMtl_4.name as string))
			ele.SetAttribute "color_blend4"  (color2String m.blend[5])
				
			try( root1.appendChild (mat2Element m.coatMtl_4) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_4 "coatShader4") ) catch ()
			ele.SetAttribute "texturemap_blend_mult4"  (m.texmap_blend_mult_4 as string)
		)
		----
		if (m.coatMtl_5 != undefined) then
		(						
			ele.SetAttribute "coatMaterial5"  (m.coatMtl_5.name as string)
			ele.SetAttribute "fbxcoatMaterial5"  (fbxtext2Hex (m.coatMtl_5.name as string))
			ele.SetAttribute "color_blend5"  (color2String m.blend[6])
			try( root1.appendChild (mat2Element m.coatMtl_5) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_5 "coatShader5")  ) catch ()
			ele.SetAttribute "texturemap_blend_mult5"  (m.texmap_blend_mult_5 as string)
		)
		----
		if (m.coatMtl_6 != undefined) then
		(						
			ele.SetAttribute "coatMaterial6"  (m.coatMtl_6.name as string)
			ele.SetAttribute "fbxcoatMaterial6"  (fbxtext2Hex (m.coatMtl_6.name as string))
			ele.SetAttribute "color_blend6"  (color2String m.blend[7])
			try( root1.appendChild (mat2Element m.coatMtl_6) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_6 "coatShader6") ) catch ()
			ele.SetAttribute "texturemap_blend_mult6"  (m.texmap_blend_mult_6 as string)
		)
		----
		if (m.coatMtl_7 != undefined) then
		(						
			ele.SetAttribute "coatMaterial7"  (m.coatMtl_7.name as string)
			ele.SetAttribute "fbxcoatMaterial7"  (fbxtext2Hex (m.coatMtl_7.name as string))
			ele.SetAttribute "color_blend7"  (color2String m.blend[8])						
			try( root1.appendChild (mat2Element m.coatMtl_7) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_7 "coatShader7") ) catch ()
			ele.SetAttribute "texturemap_blend_mult7"  (m.texmap_blend_mult_7 as string)
		)
		----
		if (m.coatMtl_8 != undefined) then
		(						
			ele.SetAttribute "coatMaterial8"  (m.coatMtl_8.name as string)
			ele.SetAttribute "fbxcoatMaterial8"  (fbxtext2Hex (m.coatMtl_8.name as string))
			ele.SetAttribute "color_blend8"  (color2String m.blend[9])
			try( root1.appendChild (mat2Element m.coatMtl_8) ) catch ()
			try( ele.appendChild (shader2Element m.texmap_blend_8 "coatShader8") ) catch ()
			ele.SetAttribute "texturemap_blend_mult8"  (m.texmap_blend_mult_8 as string)
		)
		----	
		root01.appendChild ele
		return undefined 
	)
	if (classof m == Blend) then
	(
		local ele = xml.CreateElement "blendmaterial"
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)
		ele.SetAttribute "vray"  "false"
		ele.SetAttribute "interactive"  (m.interactive as string)
		ele.SetAttribute "matType" "Blend"
		-----
		if (m.map1 != undefined) then
		(
			ele.SetAttribute "material1"  (m.map1.name as string)
			ele.SetAttribute "fbxmaterial1"  (fbxtext2Hex (m.map1.name as string))
			ele.SetAttribute "material1_enable"  (m.map1Enabled as string)
			try( root1.appendChild (mat2Element m.map1) ) catch ()
		)
		if (m.map2 != undefined) then
		(
			ele.SetAttribute "material2"  (m.map2.name as string)
			ele.SetAttribute "fbxmaterial2"  (fbxtext2Hex (m.map2.name as string))
			ele.SetAttribute "material2_enable"  (m.map2Enabled as string)
			try( root1.appendChild (mat2Element m.map2) ) catch ()
		)
		try ( ele.appendChild (shader2Element m.mask "mask")) catch ()
		ele.SetAttribute "mask_enable"  (m.maskEnabled as string)
		
		ele.SetAttribute "userCurve"  (m.useCurve as string)
		ele.SetAttribute "lower"  (m.lower as string)
		ele.SetAttribute "upper"  (m.upper as string)
		root01.appendChild ele
		return undefined 
		
	)
	if (classof m == compositematerial) then
	(
		local ele = xml.CreateElement ("blendmaterial")
		ele.SetAttribute "name"  m.name
		--ele.SetAttribute "type"  ((classof m) as string)
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)			
		ele.SetAttribute "vray"  "true"
		ele.SetAttribute "matType" "blendmaterial"
		
		if (m.materialList[1]!= undefined) then
		(
			ele.SetAttribute "base_material" (m.materialList[1].name)
			try( root1.appendChild (mat2Element m.materialList[1]) ) catch ()
		)
		
		for i=1 to  m.mapEnables.count do
		(
			ele.SetAttribute ("mapEnabled"+i as string) (m.mapEnables[i] as string)
			ele.SetAttribute ("amount"+i as string) (m.amount[i] as string)
			ele.SetAttribute ("mixType"+i as string) (m.mixType[i] as string)
			
			if (m.materialList[i+1]!= undefined) then
			(
				ele.SetAttribute ("coatMaterial"+(i-1) as string) (m.materialList[i+1].name)
				try( root1.appendChild (mat2Element m.materialList[i+1]) ) catch ()
			)
			
		)
		
		root01.appendChild ele
		return undefined 			
	)
	if (classof m == Shellac) then
	(
		--Emulate Standard Max Blend Mat
		local ele = xml.CreateElement ("blendmaterial")
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)			
		ele.SetAttribute "vray"  "false"
		ele.SetAttribute "shellacColorBlend"  (m.shellacColorBlend as string)
		ele.SetAttribute "matType" "Shellac"
		
		if (m.shellacMtl1 != undefined) then
		(
			ele.SetAttribute "material1"  (m.shellacMtl1.name as string)
			try( root1.appendChild (mat2Element m.shellacMtl1) ) catch ()
		)															
		if (m.shellacMtl2 != undefined) then
		(
			ele.SetAttribute "material2"  (m.shellacMtl2.name as string)
			try( root1.appendChild (mat2Element m.shellacMtl2) ) catch ()
		)															
		root01.appendChild ele	
		return undefined 
	)		
	if (classof m == VRayOverrideMtl) then
	(
		local ele = xml.CreateElement "overridematerial"
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)
		ele.SetAttribute "vray"  "true"
		ele.SetAttribute "matType" "VRayOverrideMtl"
		
		ele.SetAttribute "giOn" (m.giMtl_on as string)
		ele.SetAttribute "reflectOn" (m.reflectMtl_on as string)
		ele.SetAttribute "refractOn" (m.refractMtl_on  as string)
		ele.SetAttribute "shadowOn" (m.shadowMtl_on as string)
		-----
		if (m.baseMtl != undefined) then
		(
			ele.SetAttribute "baseMaterial"  (m.baseMtl.name as string)
			ele.SetAttribute "fbxbaseMaterial"  (fbxtext2Hex (m.baseMtl.name  as string))
			try( root1.appendChild (mat2Element m.baseMtl) ) catch ()
		)								
		-----
		if (m.giMtl != undefined) then
		(
			ele.SetAttribute "giMaterial"  (m.giMtl.name as string)
			ele.SetAttribute "fbxgiMaterial"  (fbxtext2Hex (m.giMtl.name  as string))
			try( root1.appendChild (mat2Element m.giMtl) ) catch ()
		)						
		-----
		if (m.reflectMtl != undefined) then
		(
			ele.SetAttribute "reflectMaterial"  (m.reflectMtl.name as string)
			ele.SetAttribute "fbxreflectMaterial"  (fbxtext2Hex (m.reflectMtl.name  as string))
			try( root1.appendChild (mat2Element m.reflectMtl) ) catch ()
		)						
		-----
		if (m.refractMtl != undefined) then
		(
			ele.SetAttribute "refractMaterial"  (m.refractMtl.name as string)
			ele.SetAttribute "fbxrefractMaterial"  (fbxtext2Hex (m.refractMtl.name  as string))
			try( root1.appendChild (mat2Element m.refractMtl) ) catch ()
		)						
		-----
		if (m.shadowMtl != undefined) then
		(
			ele.SetAttribute "shadowMaterial"  (m.shadowMtl.name as string)
			ele.SetAttribute "fbxshadowMaterial"  (fbxtext2Hex (m.shadowMtl.name  as string))
			try( root1.appendChild (mat2Element m.shadowMtl) ) catch ()
		)		
		root03.appendChild ele						
		return undefined 
	)
	if (classof m == VRay2SidedMtl) then
	(
		local ele = xml.CreateElement "twosidedmaterial"
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "vray"  "true"
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)
		ele.SetAttribute "matType" "VRay2SidedMtl"
		
		ele.SetAttribute "translucency"  (color2String m.translucency)
		ele.SetAttribute "backMtlOn" (m.backMtlOn as string)
		ele.SetAttribute "texmapTranslucencyMultiplier" (m.texmap_translucency_multiplier as string)
		ele.SetAttribute "texmapTranslucencyOn" (m.texmap_translucency_on  as string)
		ele.SetAttribute "force1SidedSubMtls" (m.force1SidedSubMtls as string)
		-----
		if (m.frontMtl != undefined) then
		(
			ele.SetAttribute "frontMaterial"  (m.frontMtl.name as string)
			try( root1.appendChild (mat2Element m.frontMtl) ) catch ()
		)															
		if (m.backMtl != undefined) then
		(
			ele.SetAttribute "backMaterial"  (m.backMtl.name as string)
			try( root1.appendChild (mat2Element m.backMtl) ) catch ()
		)															
		if (m.texmap_translucency != undefined) then
		(
			ele.appendChild (shader2Element m.texmap_translucency "texmapTranslucency")
		)
		root02.appendChild ele	
		return undefined 
		
	)
	if (classof m == DoubleSided) then
	(
		local ele = xml.CreateElement "twosidedmaterial"
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "vray"  "false"
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)
		ele.SetAttribute "matType" "DoubleSided"
		
		trans = int(m.Translucency*255) as string
		ele.SetAttribute "translucency"  (trans+" "+trans+" "+trans)
		ele.SetAttribute "backMtlOn" (m.map1enabled as string)
		
		if (m.material1 != undefined) then
		(
			ele.SetAttribute "frontMaterial"  (m.material1.name as string)
			try( root1.appendChild (mat2Element m.material1) ) catch ()
		)															
		if (m.material2 != undefined) then
		(
			ele.SetAttribute "backMaterial"  (m.material2.name as string)
			try( root1.appendChild (mat2Element m.material2) ) catch ()
		)	
		root02.appendChild ele	
		return undefined
	)
	if (classof m == TopBottom) then
	(
		local ele = xml.CreateElement "topbottom"
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "vray"  "false"
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)
		ele.SetAttribute "matType" "TopBottom"
		
		ele.SetAttribute "map1Enabled" (m.map1Enabled as string)
		ele.SetAttribute "map2Enabled" (m.map2Enabled as string)
		ele.SetAttribute "blend" (m.blend as string)
		ele.SetAttribute "position" (m.position  as string)
		ele.SetAttribute "coordinates" (#("World","Local")[m.coordinates+1])
		-----
		if (m.topMaterial != undefined) then
		(
			ele.SetAttribute "topMaterial"  (m.topMaterial.name as string)
			try( root1.appendChild (mat2Element m.topMaterial) ) catch ()
		)															
		if (m.bottomMaterial != undefined) then
		(
			ele.SetAttribute "bottomMaterial"  (m.bottomMaterial.name as string)
			try( root1.appendChild (mat2Element m.bottomMaterial) ) catch ()
		)															
		root08.appendChild ele	
		return undefined 
		
	) 
	
	if (classof m == VRayCarPaintMtl) then
	(
		local ele = xml.CreateElement "carpaintmaterial"
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "vray"  "true"
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)
		ele.SetAttribute "matType" "VRayCarPaintMtl"

		ele.SetAttribute "base_color"  (color2String m.base_color)
		ele.SetAttribute "base_reflection" (m.base_reflection as string)
		ele.SetAttribute "base_glossiness" (m.base_glossiness as string)
		ele.SetAttribute "base_trace_reflections" (m.base_trace_reflections  as string)
		ele.SetAttribute "flake_color"  (color2String m.flake_color)
		ele.SetAttribute "flake_glossiness" (m.flake_glossiness as string)
		ele.SetAttribute "flake_orientation" (m.flake_orientation as string)
		ele.SetAttribute "flake_density" (m.flake_density as string)
		ele.SetAttribute "flake_scale" (m.flake_scale as string)
		ele.SetAttribute "flake_size" (m.flake_size as string)
		ele.SetAttribute "flake_seed" (m.flake_seed as string)
		ele.SetAttribute "flake_filtering" (#("Simple","Directional")[m.flake_filtering+1])
		ele.SetAttribute "flake_map_size" (m.flake_map_size as string)
		ele.SetAttribute "flake_mapping_type" (#("Explicit UVW channel","triplanar from Object XYZ")[m.flake_mapping_type+1])
		ele.SetAttribute "flake_map_channel" (m.flake_map_channel as string)
		ele.SetAttribute "flake_trace_reflections" (m.flake_trace_reflections as string)
		ele.SetAttribute "coat_color"  (color2String m.coat_color)
		ele.SetAttribute "coat_strength" (m.coat_strength as string)
		ele.SetAttribute "coat_glossiness" (m.coat_glossiness as string)
		ele.SetAttribute "coat_trace_reflections" (m.coat_trace_reflections as string)
		ele.SetAttribute "trace_reflections" (m.trace_reflections as string)
		ele.SetAttribute "double_sided" (m.double_sided as string)
		ele.SetAttribute "subdivs" (m.subdivs as string)
		ele.SetAttribute "cutoff_threshold" (m.cutoff_threshold as string)
		ele.SetAttribute "environment_priority" (m.environment_priority as string)
		-----
		
		if (m.texmap_base_color != undefined) then
		(
			ele.SetAttribute "texmap_base_color_on"  (m.texmap_base_color_on as string)
			ele.SetAttribute "texmap_base_color_multiplier"  (m.texmap_base_color_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_base_color "texmap_base_color") ) catch ()
		)															
		
		if (m.texmap_base_reflection != undefined) then
		(
			ele.SetAttribute "texmap_base_reflection_on"  (m.texmap_base_reflection_on as string)
			ele.SetAttribute "texmap_base_reflection_multiplier"  (m.texmap_base_reflection_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_base_reflection "texmap_base_reflection") ) catch ()
		)		
	
		if (m.texmap_base_glossiness != undefined) then
		(
			ele.SetAttribute "texmap_base_glossiness_on"  (m.texmap_base_glossiness_on as string)
			ele.SetAttribute "texmap_base_glossiness_multiplier"  (m.texmap_base_glossiness_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_base_glossiness "texmap_base_glossiness") ) catch ()
		)															
		
		if (m.texmap_base_bump != undefined) then
		(
			ele.SetAttribute "texmap_base_bump_on"  (m.texmap_base_bump_on as string)
			ele.SetAttribute "texmap_base_bump_multiplier"  (m.texmap_base_bump_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_base_bump "texmap_base_bump" ) ) catch ()
		)															
		if (m.texmap_flake_color != undefined) then
		(
			ele.SetAttribute "texmap_flake_color_on"  (m.texmap_flake_color_on as string)
			ele.SetAttribute "texmap_flake_color_multiplier"  (m.texmap_flake_color_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_flake_color "texmap_flake_color") ) catch ()
		)															

		if (m.texmap_flake_glossiness != undefined) then
		(
			ele.SetAttribute "texmap_flake_glossiness_on"  (m.texmap_flake_glossiness_on as string)
			ele.SetAttribute "texmap_flake_glossiness_multiplier"  (m.texmap_flake_glossiness_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_flake_glossiness "texmap_flake_glossiness") ) catch ()
		)															
		if (m.texmap_flake_orientation != undefined) then
		(
			ele.SetAttribute "texmap_flake_orientation_on"  (m.texmap_flake_orientation_on as string)
			ele.SetAttribute "texmap_flake_glossiness_multiplier"  (m.texmap_flake_glossiness_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_flake_orientation  "texmap_flake_orientation") ) catch ()
		)															
		if (m.texmap_coat_color != undefined) then
		(
			ele.SetAttribute "texmap_coat_color_on"  (m.texmap_coat_color_on as string)
			ele.SetAttribute "texmap_coat_color_multiplier"  (m.texmap_coat_color_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_coat_color  "texmap_coat_color") ) catch ()
		)			
	
		if (m.texmap_coat_strength != undefined) then
		(
			ele.SetAttribute "texmap_coat_strength_on"  (m.texmap_coat_strength_on as string)
			ele.SetAttribute "texmap_coat_strength_multiplier"  (m.texmap_coat_strength_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_coat_strength "texmap_coat_strength") ) catch ()
		)			

		if (m.texmap_coat_glossiness != undefined) then
		(
			ele.SetAttribute "texmap_coat_glossiness_on"  (m.texmap_coat_glossiness_on as string)
			ele.SetAttribute "texmap_coat_glossiness_multiplier"  (m.texmap_coat_glossiness_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_coat_glossiness "texmap_coat_glossiness") ) catch ()
		)	

		if (m.texmap_coat_bump != undefined) then
		(
			ele.SetAttribute "texmap_coat_bump_on"  (m.texmap_coat_bump_on as string)
			ele.SetAttribute "texmap_coat_bump_multiplier"  (m.texmap_coat_bump_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_coat_bump "texmap_coat_bump") ) catch ()
		)	

		if (m.texmap_environment_override != undefined) then
		(
			ele.SetAttribute "texmap_environment_override_on"  (m.texmap_environment_override_on as string)
			try( ele.appendChild (shader2Element m.texmap_environment_override "texmap_environment_override") ) catch ()
		)	

		if (m.texmap_displacement != undefined) then
		(
			ele.SetAttribute "texmap_displacement_on"  (m.texmap_displacement_on as string)
			ele.SetAttribute "texmap_displacement_multiplier"  (m.texmap_displacement_multiplier as string)
			try( ele.appendChild (shader2Element m.texmap_displacement "texmap_displacement") ) catch ()
		)	

		root05.appendChild ele	
		return undefined 
		
	)		
	if (classof m == VRayFastSSS2) then
	(
		local ele = xml.CreateElement ("fastsss2material")
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "vray"  "true"
		ele.SetAttribute "fbxname"  (fbxtext2Hex m.name)
		ele.SetAttribute "matType" "VRayFastSSS2"
		
		ele.SetAttribute "sss2_preset" (m.preset as string)
		ele.SetAttribute "sss2_scale" (m.scale as string)
		ele.SetAttribute "sss2_IOR" (m.IOR  as string)
		
		ele.SetAttribute "sss2_multiple_scattering" (#("Prepass-based illumination map","Object-based illumination map","Raytraced")[m.multiple_scattering+1])
		ele.SetAttribute "sss2_prepass_rate" (m.prepass_rate as string)
		ele.SetAttribute "sss2_prepass_id" (m.prepass_id  as string)
		
		ele.SetAttribute "sss2_auto_calculate_density" (m.auto_calculate_density as string)
		ele.SetAttribute "sss2_samples_per_unit_area" (m.samples_per_unit_area as string)
		ele.SetAttribute "sss2_surface_offset" (m.surface_offset as string)
		ele.SetAttribute "sss2_preview_samples" (m.preview_samples as string)
		ele.SetAttribute "sss2_max_distance" (m.max_distance as string)
		
		ele.SetAttribute "sss2_background_color"  (color2String m.background_color)
		ele.SetAttribute "sss2_samples_color"  (color2String m.samples_color)
		
		ele.SetAttribute "sss2_diffuse_color"  (color2String m.diffuse_color)
		ele.SetAttribute "sss2_diffuse_amount" (m.diffuse_amount  as string)
		ele.SetAttribute "sss2_sub_surface_color"  (color2String m.sub_surface_color)
		ele.SetAttribute "sss2_scatter_color"  (color2String m.scatter_color)
		ele.SetAttribute "sss2_scatter_radius" (m.scatter_radius as string)
		
		ele.SetAttribute "sss2_phase_function" (m.phase_function as string)
		ele.SetAttribute "sss2_specular_color"  (color2String m.specular_color)
		ele.SetAttribute "sss2_specular_amount" (m.specular_amount as string)
		ele.SetAttribute "sss2_specular_glossiness" (m.specular_glossiness as string)
		ele.SetAttribute "sss2_specular_subdivs" (m.specular_subdivs as string)
		
		ele.SetAttribute "sss2_trace_reflections" (m.trace_reflections as string)
		ele.SetAttribute "sss2_reflection_depth" (m.reflection_depth as string)
		ele.SetAttribute "sss2_single_scatter" (#("None","Single","Raytraced (solid)","Raytraced (refractive)")[m.single_scatter+1])
		
		ele.SetAttribute "sss2_single_scatter_subdivs" (m.single_scatter_subdivs as string)
		ele.SetAttribute "sss2_refraction_depth" (m.refraction_depth as string)
		
		ele.SetAttribute "sss2_front_lighting" (m.front_lighting as string)
		ele.SetAttribute "sss2_back_lighting" (m.back_lighting as string)
		ele.SetAttribute "sss2_scatter_gi" (m.scatter_gi as string)
		try ( ele.SetAttribute "sss2_prepass_LOD_threshold" (m.prepass_LOD_threshold as string) ) catch ()
		try ( ele.SetAttribute "sss2_interpolation_accuracy" (m.interpolation_accuracy as string) ) catch ()
		try ( ele.SetAttribute "sss2_legacy_mode" (m.legacy_mode as string) ) catch ()
		try ( ele.SetAttribute "sss2_prepass_blur" (m.prepass_blur as string) ) catch ()
		try ( ele.SetAttribute "sss2_cutoff_threshold" (m.cutoff_threshold as string) ) catch ()
		try ( ele.SetAttribute "sss2_prepass_mode" (#("Single frame","Single frame(autosave)","From file")[m.prepass_mode+1]) ) catch ()
		try ( ele.SetAttribute "sss2_prepass_fileName" (m.prepass_fileName as string) ) catch ()
		
		if (m.texmap_bump != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_bump_on"  (m.texmap_bump_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_bump_multiplier"  (m.texmap_bump_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_bump "sss2_texmap_bump") ) catch ()
		)															
		
		if (m.texmap_overall_color != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_overall_color_on"  (m.texmap_overall_color_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_overall_color_multiplier"  (m.texmap_overall_color_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_overall_color "sss2_texmap_overall_color") ) catch ()
		)	
		if (m.texmap_diffuse_color != undefined) then
		(
			try ( ele.SetAttribute "sss2_sss2_texmap_diffuse_color_on"  (m.texmap_diffuse_color_on as string) )catch()
			try ( ele.SetAttribute "sss2_sss2_texmap_diffuse_color_multiplier"  (m.texmap_diffuse_color_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_diffuse_color "sss2_texmap_diffuse_color") ) catch ()
		)	
		
		if (m.texmap_diffuse_amount != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_diffuse_amount_on"  (m.texmap_diffuse_amount_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_diffuse_amount_multiplier"  (m.texmap_diffuse_amount_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_diffuse_amount "sss2_texmap_diffuse_amount") ) catch ()
		)			
		
		if (m.texmap_specular_color != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_specular_color_on"  (m.texmap_specular_color_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_specular_color_multiplier"  (m.texmap_specular_color_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_specular_color "sss2_texmap_specular_color") ) catch ()
		)	
		if (m.texmap_specular_amount != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_specular_amount_on"  (m.texmap_specular_amount_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_specular_amount_multiplier"  (m.texmap_specular_amount_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_specular_amount "sss2_texmap_specular_amount") ) catch ()
		)	
		if (m.texmap_specular_glossiness != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_specular_glossiness_on"  (m.texmap_specular_glossiness_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_specular_glossiness_multiplier"  (m.texmap_specular_glossiness_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_specular_glossiness "sss2_texmap_specular_glossiness") ) catch ()
		)				
		if (m.texmap_sss_color != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_sss_color_on"  (m.texmap_sss_color_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_sss_color_multiplier"  (m.texmap_sss_color_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_sss_color "sss2_texmap_sss_color") ) catch ()
		)				
		if (m.texmap_scatter_color != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_scatter_color_on"  (m.texmap_scatter_color_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_scatter_color_multiplier"  (m.texmap_scatter_color_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_scatter_color "sss2_texmap_scatter_color") ) catch ()
		)				
		if (m.texmap_scatter_radius != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_scatter_radius_on"  (m.texmap_scatter_radius_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_scatter_radius_multiplier"  (m.texmap_scatter_radius_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_scatter_radius "sss2_texmap_scatter_radius") ) catch ()
		)	
		if (m.texmap_displacement != undefined) then
		(
			try ( ele.SetAttribute "sss2_texmap_displacement_on"  (m.texmap_displacement_on as string) )catch()
			try ( ele.SetAttribute "sss2_texmap_displacement_multiplier"  (m.texmap_displacement_multiplier as string) )catch()
			try( ele.appendChild (shader2Element m.texmap_displacement "sss2_texmap_displacement") ) catch ()
		)				
		root07.appendChild ele	
		return undefined 
	)
	if (classof  m == VRayLightMtl) then
	(
		local ele = xml.CreateElement ("vraylightmtl")
		ele.SetAttribute "name"  m.name
		ele.SetAttribute "vray"  "true"
		ele.SetAttribute "fbxname" (fbxtext2Hex mat.name)
		ele.SetAttribute "matType" "VRayLightMtl"

		try ele.SetAttribute ("color") (color2String  m.color) catch ()
		try ele.SetAttribute ("multiplier") (m.multiplier as string) catch ()		
		try ele.SetAttribute ("twoSided") (m.twoSided as string) catch ()		
		try ele.SetAttribute ("compemsate_exposure") (m.compensate_exposure as string) catch ()		
		try ele.SetAttribute ("textmap_on") (m.texmap_on as string) catch ()
		try ele.SetAttribute ("opacity_texmap_on") (m.opacity_texmap_on as string) catch ()
		try ele.SetAttribute ("opacity_multiplyColor") (m.opacity_multiplyColor as string) catch ()
		try ele.SetAttribute ("displacement_texmap_on") (m.displacement_texmap_on as string) catch ()
		
		try ele.SetAttribute ("directLight_on") (m.directLight_on as string) catch ()
		try ele.SetAttribute ("directLight_subdivs") (m.directLight_subdivs as string) catch ()
		try ele.SetAttribute ("directLight_cutoffThreshold") (m.directLight_cutoffThreshold as string) catch ()
		try ele.SetAttribute ("displacement_multiplier") (m.displacement_multiplier as string) catch ()
		try ele.SetAttribute ("texmap_resolution") (m.texmap_resolution as string) catch ()
		try ele.SetAttribute ("texmap_adaptiveness") (m.texmap_adaptiveness as string) catch ()


		try ( ele.appendChild (shader2Element m.texmap "vraylightlightmap")) catch ()		
		try ( ele.appendChild (shader2Element m.opacity_texmap "vraylightopacitymap")) catch ()		
		try ( ele.appendChild (shader2Element m.displacement_texmap "vraylightdisplacementmap")) catch ()		
		return ele
	)		
	
	if (m != undefined) then
	(
		local ele = xml.CreateElement "material"
		local is_Vray = false
		local matNameLower = tolower (mat as string)
		local prefix = ""
		
		try
		(
			ele.SetAttribute "name" mat.name
			ele.SetAttribute "fbxname" (fbxtext2Hex mat.name)
			if (findString matNameLower "vray" != undefined) then
			(
				is_Vray = true
				prefix = "vray"
			)
			
		)catch(
			ele.SetAttribute "name" "noname"
			ele.SetAttribute "fbxname" (fbxtext2Hex "noname")
		)
		
		ele.SetAttribute "vray" (is_Vray as string)
		
		if (is_Vray) then
		(
			ele.SetAttribute "matType" "VRayMtl"
			try ele.SetAttribute (prefix+"reflection_color") (color2String  mat.Reflection) catch ()
			try ele.SetAttribute (prefix+"hilight_glossiness") ((mat.hilight_glossiness) as string) catch ()		
			try ele.SetAttribute (prefix+"reflection_glossiness") ((mat.reflection_glossiness) as string) catch ()
			try ele.SetAttribute (prefix+"reflection_fresnel") ((mat.reflection_fresnel) as string) catch ()
			try ele.SetAttribute (prefix+"reflection_ior") ((mat.reflection_ior) as string) catch ()
			try ele.SetAttribute (prefix+"reflection_lockGloss") ((mat.reflection_lockGlossiness) as string) catch ()
			try ele.SetAttribute (prefix+"reflection_lockIOR") ((mat.reflection_lockIOR) as string) catch ()
			
			try ele.SetAttribute (prefix+"selfillum_color") (color2String mat.selfIllumination) catch ()
			try ele.SetAttribute (prefix+"refraction_color") (color2String  mat.Refraction) catch ()
			try ele.SetAttribute (prefix+"refraction_glossiness") ((mat.refraction_glossiness) as string) catch ()		
			try ele.SetAttribute (prefix+"refraction_ior") ((mat.refraction_ior) as string) catch ()
			try ele.SetAttribute (prefix+"refraction_affectShadows") ((mat.refraction_affectShadows) as string) catch ()
			try ele.SetAttribute (prefix+"brdf_type") ((mat.brdf_type) as string) catch ()
			
			try ele.SetAttribute (prefix+"diffuse_value")  ((mat.texmap_diffuse_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"roughhness_value")  ((mat.texmap_roughness_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"self_illumination_value")  ((mat.texmap_self_illumination_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"reflection_value")  ((mat.texmap_reflection_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"hilightGlossiness_value")  ((mat.texmap_hilightGlossiness_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"reflectionGlossiness_value")  ((mat.texmap_reflectionGlossiness_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"reflectionIOR_value")  ((mat.texmap_reflectionIOR_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"anisotropy_value")  ((mat.texmap_anisotropy_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"anisotropy_rotation_value")  ((mat.texmap_anisotropy_rotation_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"refraction_value")  ((mat.texmap_refraction_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"refractionGlossiness_value")  ((mat.texmap_refractionGlossiness_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"refractionIOR_value")  ((mat.texmap_refractionIOR_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"translucent_value")  ((mat.texmap_translucent_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"refraction_fog_value")  ((mat.texmap_refraction_fog_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"bump_value")  ((mat.texmap_bump_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"displacement_value")  ((mat.texmap_displacement_multiplier) as string) catch ()
			try ele.SetAttribute (prefix+"opacity_value")  ((mat.texmap_opacity_multiplier) as string) catch ()
			
			try(	ele.appendChild (shader2Element mat.texmap_diffuse "diffuse_map")	) catch()			
			try(	ele.appendChild (shader2Element mat.texmap_bump "bump_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.texmap_reflection "reflection_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.texmap_refraction "refraction_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.texmap_reflectionGlossiness "vrayreflection_glossiness_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.texmap_refractionGlossiness "vrayrefraction_glossiness_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.texmap_hilightGlossiness "vrayhilight_glossiness_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.texmap_opacity "opacity_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.texmap_self_illumination "self_illumination_map")	) catch ()

		)	
		else
		(
			ele.SetAttribute "matType" "Standardmaterial"
			try(	ele.appendChild (shader2Element mat.diffusemap "diffuse_map") ) catch()
			try(	ele.appendChild (shader2Element mat.opacityMap "opacity_map")) catch()
			try(	ele.appendChild (shader2Element mat.bumpMap "bump_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.reflectionMap "reflection_map")	) catch ()
			try(	ele.appendChild (shader2Element mat.selfIllumMap "self_illumination_map")	) catch ()				
			
			try ele.SetAttribute (prefix+"ambient_value")  ((mat.ambientMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"diffuse_value")  ((mat.diffuseMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"specular_value")  ((mat.specularMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"specularLevel_value")  ((mat.specularLevelMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"glossiness_value")  ((mat.glossinessMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"selfillum_value")  ((mat.selfillumMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"opacity_value")  ((mat.opacityMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"filter_value")  ((mat.filterMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"bump_value")  ((mat.bumpMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"reflection_value")  ((mat.reflectionMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"refraction_value")  ((mat.refractionMapAmount) as string) catch ()
			try ele.SetAttribute (prefix+"displacement_value")  ((mat.displacementMapAmount) as string) catch ()
		)
			try ele.SetAttribute (prefix+"opacity_amount")  ((mat.opacity) as string) catch ()
			try ele.SetAttribute (prefix+"specular_width") (replacestring ((mathlib.round mat.glossiness) as string) ".0d0" "") catch ()
			try ele.SetAttribute (prefix+"specularLevel") (replacestring  ((mathlib.round mat.specularLevel) as string) ".0d0" "") catch ()
			try ele.SetAttribute (prefix+"glossiness") (replacestring ((mathlib.round mat.glossiness) as string) ".0d0" "") catch ()
			try ele.SetAttribute (prefix+"soften") (replacestring ((mathlib.round mat.soften) as string) ".0d0" "") catch ()
			try ele.SetAttribute (prefix+"specular_color") (color2String  mat.Specular) catch ()
			try ele.SetAttribute (prefix+"diffuse_color") (color2String  mat.Diffuse) catch ()
			try ele.SetAttribute (prefix+"self_illum_slider")  ((mat.selfIllumAmount) as string) catch ()
			
		return ele
	)
)

function isUsedMat mat =
(
	for obj in geometry do
		if (obj.mat == mat) then
			return true
	return false
)

function getFilterKernelName obj = 
(
	local s = obj as string
	local i = findstring s ":"
	if (i != undefined) then
		return substring s 1 (i-1)
	else
		return s
)

function collectAllSingleMaterial =
(
	local listmat =#()
	for m in scenematerials do 
		if (isUsedMat m) then
		(
			local n = 0
			try (
				n = m.count 
			)	catch ()
			if (n==0) then
				append listmat m
			else
				for mat in m do
					append listmat mat
		)	
	return listmat
)

function isNeed2Standard m= 
(
	local list=#(Blend,Shellac,compositematerial,Topbottom)
	if (isVray m) then
		return true
	for i in list do
		if (classOf m == i) then
			return true
	return false
)

function isInListMaterial m = 
(
	local list=#(VRayBlendMtl,VRayOverrideMtl,Blend,Shellac,compositematerial,VrayLightMtl,Topbottom)
	for i in list do
		if (classOf m == i) then
			return true
	return false
)

function submatRecursion m listmat1=
(
	print ("-----------------Running Recursion ( "+m.name+" )")
	try
	(
		--append listmat1 m
		if (classof m == VRayBlendMtl) then
		(
			if (m.basemtl != undefined) then
				if (isInListMaterial m.basemtl) then
					submatRecursion m.basemtl listmat1
				else
					append listmat1 m.basemtl
			if (m.coatMtl_0 != undefined) then
				if (isInListMaterial m.coatMtl_0) then
					submatRecursion m.coatMtl_0 listmat1
				else
					append listmat1 m.coatMtl_0
			if (m.coatMtl_1 != undefined) then
				if (isInListMaterial m.coatMtl_1) then
					submatRecursion m.mcoatMtl_1 listmat1
				else
					append listmat1 m.coatMtl_1
			if (m.coatMtl_2 != undefined) then
				if (isInListMaterial m.coatMtl_2) then
					submatRecursion m.coatMtl_2 listmat1
				else
					append listmat1 m.coatMtl_2
			if (m.coatMtl_3 != undefined) then
				if (isInListMaterial m.coatMtl_3) then
					submatRecursion m.coatMtl_3 listmat1
				else
					append listmat1 m.coatMtl_3
			if (m.coatMtl_4 != undefined) then
				if (isInListMaterial m.coatMtl_4) then
					submatRecursion m.coatMtl_4 listmat1
				else
					append listmat1 m.coatMtl_4
			if (m.coatMtl_5 != undefined) then
				if (isInListMaterial m.coatMtl_5) then
					submatRecursion m.coatMtl_5 listmat1
				else
					append listmat1 m.coatMtl_5
			if (m.coatMtl_6 != undefined) then
				if (isInListMaterial m.coatMtl_6) then
					submatRecursion m.coatMtl_6 listmat1
				else
					append listmat1 m.coatMtl_6
			if (m.coatMtl_7 != undefined) then
				if (isInListMaterial m.coatMtl_7) then
					submatRecursion m.coatMtl_7 listmat1
				else
					append listmat1 mcoatMtl_7
			if (m.coatMtl_8 != undefined) then
				if (isInListMaterial m.coatMtl_8) then
					submatRecursion m listmat1
				else
					append listmat1 m.coatMtl_8
		)
		else if (classof m == Blend) then
		(
			if (m.map1 != undefined) then
				if (isInListMaterial m.map1) then
					submatRecursion m.map1 listmat1
				else
					append listmat1 m.map1
			if (m.map2 != undefined) then
				if (isInListMaterial m.map2) then
					submatRecursion m.map2 listmat1
				else
					append listmat1 m.map2
		)
		else if (classof m == Shellac) then
		(
			if (m.shellacMtl1 != undefined) then
				if (isInListMaterial m.shellacMtl1) then
					submatRecursion m.shellacMtl1 listmat1
				else
					append listmat1 m.shellacMtl1
			if (m.shellacMtl2 != undefined) then
				if (isInListMaterial m.shellacMtl2) then
					submatRecursion m.shellacMtl2 listmat1
				else
					append listmat1 m.shellacMtl2
		)
		else if (classof m == Topbottom) then
		(
			if (m.topMaterial != undefined) then
				if (isInListMaterial m.topMaterial) then
					submatRecursion m.topMaterial listmat1
				else
					append listmat1 m.topMaterial
			if (m.bottomMaterial != undefined) then
				if (isInListMaterial m.bottomMaterial) then
					submatRecursion m.bottomMaterial listmat1
				else
					append listmat1 m.bottomMaterial
		)			
		else if (classof m == compositematerial) then
		(
			
			for i=1 to  m.materialList.count do
			(
				if (m.materialList[i] != undefined) then
					if (isInListMaterial m.materialList[i]) then
						submatRecursion m.materialList[i] listmat1
					else
						append listmat1 m.materialList[i]
			)
		)
		else if (classof m == VRayOverrideMtl) then
		(
			if (m.baseMtl != undefined) then
				if (isInListMaterial m.baseMtl) then
					submatRecursion m.baseMtl listmat1
				else
					append listmat1 m.baseMtl
			if (m.giMtl != undefined) then
				if (isInListMaterial m.giMtl) then
					submatRecursion m.giMtl listmat1
				else
					append listmat1 mgiMtl
			if (m.reflectMtl != undefined) then
				if (isInListMaterial m.reflectMtl) then
					submatRecursion m.reflectMtl listmat1
				else
					append listmat1 m.reflectMtl
			if (m.refractMtl != undefined) then
				if (isInListMaterial m.refractMtl) then
					submatRecursion m.refractMtl listmat1
				else
					append listmat1 m.refractMtl
			if (m.shadowMtl != undefined) then
				if (isInListMaterial m.shadowMtl) then
					submatRecursion m.shadowMtl listmat1
				else
					append listmat1 m.shadowMtl
		)
	)
	catch ()
	return listmat1
)

function c01_getBaseMtl mat =
(
	local temp = mat
	while classof temp.basemtl == VRayBlendMtl do
		temp = temp.basemtl
	return temp.basemtl
)
function c01_fixVrayblend obj i =
(
	if i==0 then
	(
		if classof obj.mat == VRayBlendMtl then
		(
			local t =  obj.mat.name
			obj.mat = c01_getBaseMtl obj.mat
			obj.mat.name = t
		)
	)
	else
		if classof obj.mat[i] == VRayBlendMtl then
		(
			local t =  obj.mat[i].name
			obj.mat[i] = c01_getBaseMtl obj.mat[i]
			obj.mat[i].name = t
		)
)
function c01_Simplifier =
(

	max select all
	for obj in selection do
		if classOf obj.mat == Multimaterial then
		(
			for i=1 to obj.mat.count do
			(
				c01_fixVrayblend obj i
			)
		)
		else
			c01_fixVrayblend obj 0

)

function removeDisplacements =
	(
	for i in objects do for j=1 to i.modifiers.count do if (classof i.modifiers[j]) == VRayDisplacementMod do deleteModifier i j
	)

function c02_saveRenderMap subShader filename=
(
	local rm = renderMap subShader scale:100 size:[1024,1024] display:false fileName:filename
	save rm
	close rm
	return Bitmaptexture fileName:filename
)
function c02_isReady2Bake subShader =
(
	local list = #(Bitmaptexture,VRayMap,UndefinedClass)
	for l in list do
		if classOf subShader == l then
			return false
	return true
)
function c02_bakeShader mat =
(
	local p = maxFilePath+"maps_baked/"
	makeDir p all:true
	if classOf mat == VRayMtl then
	(
		if c02_isReady2Bake mat.texmap_diffuse then
			mat.texmap_diffuse = c02_saveRenderMap mat.texmap_diffuse (p+mat.name+"_diffuse.jpg")
		if c02_isReady2Bake mat.texmap_reflection then
			mat.texmap_reflection = c02_saveRenderMap mat.texmap_reflection (p+mat.name+"_reflection.jpg")
		if c02_isReady2Bake mat.texmap_refraction then
			mat.texmap_refraction = c02_saveRenderMap mat.texmap_refraction (p+mat.name+"_refraction.jpg")
		if c02_isReady2Bake mat.texmap_bump then
			mat.texmap_bump = c02_saveRenderMap mat.texmap_bump (p+mat.name+"_bump.jpg")
		try (
		print("mat.texmap_diffuse = "+mat.texmap_diffuse.filename as string)
		)catch()
		try (
		print("mat.texmap_reflection = "+mat.texmap_reflection.filename as string)
		)catch()
		try (	
		print("mat.texmap_refraction = "+mat.texmap_refraction.filename as string)
		)catch()
		try (
		print("mat.texmap_bump = "+mat.texmap_bump.filename as string)
		)catch()
	)
	if classOf mat == Standardmaterial then
	(
		if c02_isReady2Bake mat.diffuseMap then
			mat.diffuseMap = c02_saveRenderMap mat.diffuseMap (p+mat.name+"_diffuse.jpg")
		if c02_isReady2Bake mat.reflectionMap then
			mat.reflectionMap = c02_saveRenderMap mat.reflectionMap (p+mat.name+"_reflection.jpg")
		if c02_isReady2Bake mat.refractionMap then
			mat.refractionMap =c02_saveRenderMap mat.refractionMap (p+mat.name+"_refraction.jpg")
		if c02_isReady2Bake mat.bumpMap then
			mat.bumpMap = c02_saveRenderMap mat.bumpMap (p+mat.name+"_bump.jpg")
	)
	
)
function c02_BakeShaderAll =
(
	max select all
	for obj in selection do
		
		if classOf obj.mat == Multimaterial then
		(
			for i=1 to obj.mat.count do
				c02_bakeShader obj.mat[i]
		)
		else
		(
			c02_bakeShader obj.mat
		)
	GatherTexturesToTexFolder()
)	

function c03_vrtostd = 
(
	matArr = getclassinstances vraymtl
	tmpObj = box()
	for i in matArr do
	(
		 tmpObj.material = i
		 newMat = Standard()
		 newMat.diffusemap = i.texmap_diffuse
		 newMat.diffuse = i.diffuse
		 newMat.name = i.name
		 replaceInstances (tmpObj.material) newMat
	)
	delete tmpObj
)	

function c04_uniqueBumpValue =
(
	local listmat = collectAllSingleMaterial()
	local i = 0
	for m in listmat do
	(
		if classOf m == Standardmaterial then
		(
			m.bumpMapEnable = on
			i += 1
			m.bumpMapAmount = i
		)
	)			
)

function setMatAndModLists obj ele =
(
	try
	(
		if (classof obj.mat == Blend or classof obj.mat == VrayBlendMtl or classof obj.mat == Shellac or classof obj.mat == compositematerial) then
		(
			ele.SetAttribute "blendMat"  obj.mat.name
		)
		else
		(
			local matList = ""
			local n = 0
			try (
				n =obj.mat.count 
			)	catch ()
			if (n==0) then
			(
				matList += obj.mat.name
			)
			else
			(
				for i=1 to n do
				(
					if obj.mat.materialList[i] != undefined and obj.mat.mapEnabled[i] do
					(
						if matList !="" do
						(
							matList += ","
						)
						matList += obj.mat.materialList[i].name
					)
				)
			)
			ele.SetAttribute "matList"  matList
	)
	)catch()
	try
	(
		subdivs = 0
		vp_subdivs = 0
		for index = obj.modifiers.count to 1 by -1 do
		(
			--Search for VRayDisplacementModifiers
			if ((classOf obj.modifiers[index]) == VRayDisplacementMod) then
			(
				local m = obj.modifiers[index]
				local ele = xml.CreateElement ("displacementmodifier")
				ele.SetAttribute "name"  m.name
				ele.SetAttribute "vray"  "true"
				ele.SetAttribute "matType" ""
				
				ele.SetAttribute "displacementmod_type" (m.type as string)
				ele.SetAttribute "displacementmod_amount" (m.amount as string)
				ele.SetAttribute "displacementmod_shift" (m.shift as string)
				ele.SetAttribute "displacementmod_waterLevelOn" (m.waterLevelOn as string)
				ele.SetAttribute "displacementmod_waterLevelValue" (m.waterLevelValue as string)
				ele.SetAttribute "displacementmod_resolution" (m.resolution as string)
				ele.SetAttribute "displacementmod_precision" (m.precision as string)
				ele.SetAttribute "displacementmod_tightBounds" (m.tightBounds as string)
				
				ele.SetAttribute "displacementmod_Object" (obj.name as string)
				ele.appendChild  (shader2Element m.texmap "displacementmod_texmap")
				
				root09.appendChild ele
			)
			--Add up iterations of all TurboSmooth & MeshSmooth modifiers combined
			if ((classOf obj.modifiers[index]) == TurboSmooth or (classOf obj.modifiers[index]) == MeshSmooth) then
			(
				--Check for existence of parent turbo/meshsmooth
				hasParentSmooth = false
				theNode = obj
				theParent = obj
				while (theParent != undefined) do
				(
					theParent = theNode.parent
					if (theParent != undefined) then
					(
						for pindex = theParent.modifiers.count to 1 by -1 do
						(
							if ((classOf theParent.modifiers[pindex]) == TurboSmooth or (classOf theParent.modifiers[pindex]) == MeshSmooth) do
							(
								hasParentSmooth = true
							)
						)
						theNode = theParent
					)
				)
				if not hasParentSmooth then
				(
					if (obj.modifiers[index].useRenderIterations == True) then
					(
						subdivs += obj.modifiers[index].renderIterations
						vp_subdivs += obj.modifiers[index].iterations
					)
					else
					(
						subdivs += obj.modifiers[index].iterations
						vp_subdivs += obj.modifiers[index].iterations
					)
				)
			)
		)
		if (subdivs > 0) then
		(
			ele.SetAttribute "turbosmooth"  ( subdivs as string)
			ele.SetAttribute "turbosmooth_vp"  ( vp_subdivs as string)
	)
	)catch()
	return ele
)

function ShadersSimple =
	(
			matArray = getClassInstances VRayMtl
			for i in matArray do
			(
				if (classof i.texmap_diffuse) == VRayDirt do
				(
					i.diffuse = i.texmap_diffuse.unoccluded_color
					i.texmap_diffuse = undefined
				)
				if (classof i.texmap_diffuse) == falloff do
				(
					i.diffuse = i.texmap_diffuse.color1
					i.texmap_diffuse = i.texmap_diffuse.map1
				)
				if (classof i.texmap_reflection) == VRayDirt do
				(
					i.reflection = i.texmap_reflection.unoccluded_color
					i.texmap_reflection = undefined
				)
				if (classof i.texmap_reflection) == falloff do
				(
					i.reflection = i.texmap_reflection.color1
					i.texmap_reflection = undefined
				)
				if (classof i.texmap_refraction) == VRayDirt do
				(
					i.refraction = i.texmap_refraction.unoccluded_color
					i.texmap_refraction = undefined
				)
				if (classof i.texmap_refraction) == falloff do
				(
					i.refraction = i.texmap_refraction.color1
					i.texmap_refraction = i.texmap_refraction.map1
				)
			)
	)

function removeCC =
(
	matArray = getClassInstances Standard
		for i in matArray do
		(
			if (classof i.diffuseMap == Color_Correction) do
			(
				i.diffuseMap = i.diffuseMap.map
			)
		)
if (vray != undefined) then 
	(
		matArray = getClassInstances VrayMtl
		for i in matArray do
		(
			if (classof i.texmap_diffuse == Color_Correction) do
			(
				i.texmap_diffuse = i.texmap_diffuse.map
			)
		)
	)
)

function Export02 = 
(
	xml = undefined
	xml = dotNetObject "System.Xml.XmlDocument"
	local root = xml.CreateElement "settings"
	local root0 = xml.CreateElement "rsettings"
	root01 = xml.CreateElement "blendmaterials"		
	root02 = xml.CreateElement "twosidematerials"	
	root03 = xml.CreateElement "overridematerials"	
	root04 = xml.CreateElement "diffuse"
	root05 = xml.CreateElement "carpaintmaterials"
	root07 = xml.CreateElement "fastsss2materials"
	root08 = xml.CreateElement "topbottom"
	root09 = xml.CreateElement "displacementmodifiers"
	
	root20 = xml.CreateElement "renderableOff"
	root21 = xml.CreateElement "visibletoCameraOff"
	root22 = xml.CreateElement "receiveShadowsOff"
	root23 = xml.CreateElement "castShadowsOff"
	
	root1 = xml.CreateElement "materials"
	local root2 = xml.CreateElement "lights"
	local root3 = xml.CreateElement "geometrys"
	local root4 = xml.CreateElement "background"
	local root41 = xml.CreateElement "backgroundmaya"
	local root5 = xml.CreateElement "cameras"
	local root6 = xml.CreateElement "vray_sun"
	local root7 = xml.CreateElement "matte_objects"
	local vr = renderers.current
	local ver = 30

	if (findstring (vr as string) "V_Ray_Adv_2_4" != undefined) then ver = 24
	if (findstring (vr as string) "V_Ray_Adv_2_2" != undefined) then ver = 22
	
	if (findString (toLower (vr as string)) "v_ray" == 1) then
	(
		local ele = xml.CreateElement "vray_ImageSampler"
		local imgSampler = #("Fixed","Adaptive DMC","Adaptive subdivision","Progressive")
		local renderMask = #("None","Texture","Selected","Include/Exclude list","Layer")
		try ( ele.SetAttribute "imageSamplerType" imgSampler[vr.imageSampler_type+1]) catch()
		if (ver >=30) then
		(
			try( ele.SetAttribute "minShadingRate" (vr.imageSampler_shadingRate as string)) catch()
			try( ele.SetAttribute "renderMask" (renderMask[vr.imageSampler_renderMask_type+1]))catch()
		)
		try(
			ele.SetAttribute "renderMask_Texture" (getAbsolutePath vr.imageSampler_renderMask_texmap.filename)
		)catch ()
		if (ver >=30) then
		ele.SetAttribute "divideShadingSubdivs" (vr.dmc_balance_subdivs as string)
		ele.SetAttribute "filterOn" (vr.filter_on as string)
		ele.SetAttribute "filterKernel" (getFilterKernelName vr.filter_kernel)
		ele.SetAttribute "filterSize" (vr.filter_size as string)
		ele.SetAttribute "filterParamA" (vr.filter_paramA as string)
		ele.SetAttribute "filterParamB" (vr.filter_paramB as string)
		ele.SetAttribute "filterParamC" (vr.filter_paramC as string)
		root0.appendChild ele 
		
		local ele = xml.CreateElement "vray_AdaptiveImageSampler"
		ele.SetAttribute "minSubdivs" (vr.twoLevel_baseSubdivs as string)
		ele.SetAttribute "maxSubdivs" (vr.twoLevel_fineSubdivs as string)
		ele.SetAttribute "useDMCSamplerThreshold" (vr.twoLevel_useDMCSamplerThresh as string)
		ele.SetAttribute "color" (vr.twoLevel_threshold as string)
		root0.appendChild ele
		
		local ele = xml.CreateElement "vray_GlobalDMC"
		ele.SetAttribute "adaptiveAmount" (vr.dmc_earlyTermination_amount as string)
		try(
			ele.SetAttribute "timeIndependent" (vr.dmc_timeDependent as string)
		) catch()
		ele.SetAttribute "noiseThreshold" (vr.dmc_earlyTermination_threshold as string)
		ele.SetAttribute "globalSubdivsMult" (vr.dmc_subdivs_mult as string)
		ele.SetAttribute "minSample" (vr.dmc_earlyTermination_minSamples as string)
		root0.appendChild ele			
		
		local ele = xml.CreateElement "vray_Environment"
		local ele1 = xml.CreateElement "shader"
		local ele2 = xml.CreateElement "shader"


		ele.SetAttribute "giEnvironment" (vr.environment_gi_on as string)
		ele.SetAttribute "giColor" (color2String vr.environment_gi_color)
		ele.SetAttribute "giMulti" (vr.environment_gi_color_multiplier as string)
		
		ele.SetAttribute "giOn" (vr.environment_gi_on as string)
		ele.SetAttribute "giMapOn" (vr.environment_gi_map_on as string)
		
		ele.SetAttribute "rrOn" (vr.environment_rr_on as string)
		ele.SetAttribute "rrMapOn" (vr.environment_rr_map_on as string)

		if (vr.environment_gi_map!= undefined) then
		(
			ele1.SetAttribute "Type" ((classof vr.environment_gi_map) as string)
			if (classof vr.environment_gi_map == VRayHDRI) then
			(
				ele.SetAttribute "giShaderType" (#("Angular","Cubic","Spherical","Mirrored ball","3ds Max standard")[vr.environment_gi_map.mapType+1])
				ele.SetAttribute "giRotH" (vr.environment_gi_map.horizontalRotation as string)
				ele.SetAttribute "giRotV" (vr.environment_gi_map.verticalRotation as string)
				ele1.SetAttribute "Path" (getAbsolutePath vr.environment_gi_map.HDRIMapName)
			)
			else
				if (classof vr.environment_gi_map == Bitmaptexture) then
				(
					try(
						ele1.SetAttribute "Path" (getAbsolutePath vr.environment_gi_map.filename)
						) catch()
				)
			ele1.SetAttribute "Name" "giMapShader"		
			ele.appendChild ele1					
		)
		if (vr.environment_rr_map!= undefined) then
		(
			ele2.SetAttribute "Type" ((classof vr.environment_rr_map) as string)
			if (classof vr.environment_rr_map == VRayHDRI) then
			(
				ele.SetAttribute "rrShaderType" (#("Angular","Cubic","Spherical","Mirrored ball","3ds Max standard")[vr.environment_rr_map.mapType+1])
				ele.SetAttribute "rrRotH" (vr.environment_rr_map.horizontalRotation as string)
				ele.SetAttribute "rrRotV" (vr.environment_rr_map.verticalRotation as string)
				ele2.SetAttribute "Path" (getAbsolutePath vr.environment_rr_map.HDRIMapName)
			)
			else
				if (classof vr.environment_rr_map == Bitmaptexture) then
				(
					ele2.SetAttribute "Path" (getAbsolutePath vr.environment_rr_map.filename)
				)
			ele2.SetAttribute "Name" "rrMapShader"
			ele.appendChild ele2					
		)	


		ele.SetAttribute "rrColor" (color2String vr.environment_rr_color)
		ele.SetAttribute "rrMulti" (vr.environment_rr_color_multiplier as string)

		ele.SetAttribute "refractEnvironment" (vr.environment_refract_on as string)
		ele.SetAttribute "refractColor" (color2String vr.environment_refract_color)
		ele.SetAttribute "refractMulti" (vr.environment_refract_color_multiplier as string)
		ele.SetAttribute "refractMapOn" (vr.environment_refract_map_on as string)
		try(
			ele.SetAttribute "refractMapPath" (getAbsolutePath vr.environment_refract_map.filename)
		)catch ()
		
		root0.appendChild ele

		local ele = xml.CreateElement "vray_ColorMapping"
		local colorMappingType = #("Linear multiply","Exponential","HSV exponential","Intensity exponential","Gamma correction","Intensity gamma","Reinhard")
		local colorMappingMode = #("Color mapping and gamma","None","Color only")
		ele.SetAttribute "type" (colorMappingType[vr.colorMapping_type+1])
		ele.SetAttribute "multiplier" (vr.colorMapping_darkMult as string)
		ele.SetAttribute "burnValue" (vr.colorMapping_brightMult as string)
		ele.SetAttribute "gamma" (vr.colorMapping_gamma as string)
		ele.SetAttribute "subpixelMapping" (vr.colorMapping_subpixel as string)
		ele.SetAttribute "clampOutput" (vr.colorMapping_clampOutput as string)
		ele.SetAttribute "clampLevel" (vr.colorMapping_clampLevel as string)
		ele.SetAttribute "affectBG" (vr.colorMapping_affectBackground as string)
		if ((maxversion() as array)[1] > 15000) then
			ele.SetAttribute "mode" (colorMappingMode[vr.colorMapping_adaptationOnly+1])
		ele.SetAttribute "linearWorkflow" (vr.colorMapping_linearWorkflow as string)
		root0.appendChild ele
		
		local ele = xml.CreateElement "vray_GlobalIllumination"
		ele.SetAttribute "enableGI" (vr.gi_on as string)
		ele.SetAttribute "primaryEngine" (#("Irradiance map","Photon map","Brute force","Light cache")[vr.gi_primary_type+1])
		ele.SetAttribute "secondaryEngine" (#("None","Photon map","Brute force","Light cache")[vr.gi_secondary_type+1])
		ele.SetAttribute "refractCaustics" (vr.gi_refractCaustics as string)
		ele.SetAttribute "reflectCaustics" (vr.gi_reflectCaustics as string)
		root0.appendChild ele		
		
		local ele = xml.CreateElement "vray_IrradianceMap"
		ele.SetAttribute "currentPreset" (#("Custom","Very low","Low","Medium","Medium -animation","High","High -animation","Very high")[vr.gi_irradmap_preset+1])
		ele.SetAttribute "minRate" (vr.gi_irradmap_minRate as string)
		ele.SetAttribute "maxRate" (vr.gi_irradmap_maxRate as string)
		ele.SetAttribute "subdivs" (vr.gi_irradmap_subdivs as string)
		ele.SetAttribute "interpSamples" (vr.gi_irradmap_interpSamples as string)
		ele.SetAttribute "interpFrames" (vr.gi_irradmap_interpFrames as string)
		ele.SetAttribute "showCalcPhase" (vr.gi_irradmap_showCalcPhase as string)
		ele.SetAttribute "Mode" (#("Single frame","Multiframe incremental","From file","Add to current map","Incremental add to current map","Bucket mode","Animation prepass","Animation rendering")[vr.adv_irradmap_mode+1])
		root0.appendChild ele
		
		local ele = xml.CreateElement "vray_Caustics"
		ele.SetAttribute "enableCaustics" (vr.caustics_on  as string)
		ele.SetAttribute "searchDist" (vr.caustics_searchDist as string)
		ele.SetAttribute "maxPhotons" (vr.caustics_maxPhotons  as string)
		ele.SetAttribute "maxDensity" (vr.caustics_maxDensity  as string)
		ele.SetAttribute "multiplier" (vr.caustics_multiplier  as string)
		ele.SetAttribute "directVis" (vr.caustics_showCalcPhase  as string)
		root0.appendChild ele
	)


	local ele = xml.CreateElement "renderEngine"
	ele.SetAttribute "name" (getFilterKernelName vr)
	root0.appendChild ele		
	
	ele = xml.CreateElement "projectname"
	ele.SetAttribute "name" (maxFileName as string)		
	root0.appendChild ele	

	ele = xml.CreateElement "units"
	ele.SetAttribute "name" (units.DisplayType as string)		
	root0.appendChild ele	

	ele = xml.CreateElement "metric"
	ele.SetAttribute "name" (units.MetricType as string)		
	root0.appendChild ele

	ele = xml.CreateElement "sysmultiplier"
	ele.SetAttribute "name" "1248331028"		
	root0.appendChild ele
	
	ele = xml.CreateElement "sversion"
	ele.SetAttribute "name" "30"		
	root0.appendChild ele

	ele = xml.CreateElement "metmultiplier"
	ele.SetAttribute "name" "1024"		
	root0.appendChild ele

	ele = xml.CreateElement "renderMode"
	ele.SetAttribute "name" "StndRender"		
	root0.appendChild ele

	ele = xml.CreateElement "USType"
	ele.SetAttribute "name" (units.USType as string)		
	root0.appendChild ele

	ele = xml.CreateElement "USFrac"
	ele.SetAttribute "name" (units.USFrac as string)		
	root0.appendChild ele

	ele = xml.CreateElement "UnitsSystem"
	ele.SetAttribute "name" (units.SystemType as string)		
	root0.appendChild ele
	
	ele = xml.CreateElement "resolution"
	ele.SetAttribute "name" (((renderWidth) as string)+","+((renderHeight) as string))
	root0.appendChild ele		
	ele = xml.CreateElement "savePath"
	ele.SetAttribute "name" rendOutputFilename
	root0.appendChild ele	
	ele = xml.CreateElement "GammaLut" 
	ele.SetAttribute "name" ((IDisplayGamma.colorCorrectionMode != #none) as string)
	if (IDisplayGamma.colorCorrectionMode != #none) then
		ele.SetAttribute "gamma" (IDisplayGamma.gamma as string)
	root0.appendChild ele
	
	global mappingType = #("Spherical Environment","Cylindrical Environment","Shrink-wrap Environment","Screen")
	ele = xml.CreateElement "color"
	ele.SetAttribute "value" (color2String backgroundColor)
	root4.appendChild ele	
	ele = xml.CreateElement "usemap"
	ele.SetAttribute "value" (useEnvironmentMap as string)
	root4.appendChild ele
	
	ele = xml.CreateElement "back"
	ele.SetAttribute "color" (color2String backgroundColor)
	ele.SetAttribute "usemap" (useEnvironmentMap as string)
	root41.appendChild ele
	
	if (useEnvironmentMap and EnvironmentMap!= undefined) then
	(
		try( root4.appendChild (shader2Element EnvironmentMap "environmentMap") ) catch ()				
		try( root41.appendChild (shader2Element EnvironmentMap "environmentMap") ) catch ()				
	)
	
	
	
	global t2 = 0
	global t3 = 0 
	global t5 = 0 
	global t6 = 0 
	global t7 = 0
	local listmat = collectAllSingleMaterial()
	for m in listmat do
	(
		try 
		(
			if (m.diffuse == color 0 0 0) then
				m.diffuse = color 1 0 0 
		)
		catch()
	)				
	for m in listmat do 
	(
		try (
			root1.appendChild (mat2Element m)
		)catch()
	)


	local allObjects = $*
	for obj in allObjects do
	(
		try
		(
			if (obj.renderable == off) then
			(
				local ele = xml.CreateElement "renderableOff"
				ele.SetAttribute "name"  obj.name
				root20.appendChild ele
			)
		)catch()
		try
		(
			if (obj.castShadows == off) then
			(
				local ele = xml.CreateElement "castShadowsOff"
				ele.SetAttribute "name"  obj.name
				root23.appendChild ele
			)
		)catch()
		try
		(
			if (obj.receiveshadows == off) then
			(
				local ele = xml.CreateElement "receiveshadowsOff"
				ele.SetAttribute "name"  obj.name
				root22.appendChild ele
			
			)
		)catch()
		try
		(
			if (obj.primaryVisibility == off) then
			(
				local ele = xml.CreateElement "primaryVisibilityOff"
				ele.SetAttribute "name"  obj.name
				root21.appendChild ele
			)
		)catch()
		if (classOf obj == Free_Light or classOf obj == Target_Light) then
		(
			LightPos = box length: (10) width: (10) height: (10)
			LightPos.transform = obj.transform
			LightPos.name = "LIGHTPOS_"+obj.name
			
			local ele = xml.CreateElement "light"
			ele.SetAttribute "vray"  "false"
			ele.SetAttribute "name"  obj.name
			ele.SetAttribute "type" "ies"
			ele.SetAttribute "on" (obj.on as string)
			if (obj.Distribution == 3) then ele.SetAttribute "multiplier" "100"
			if (obj.castShadows) then
			(
				ele.SetAttribute "shadow" (obj.shadowGeneratorByName as string)
			)
			ele.SetAttribute "ies_distribution_type" (obj.Distribution as string)
			if (obj.useKelvin) then
			(
				ele.SetAttribute "ies_kelvin" (obj.kelvin as string)
			)
			if (obj.intensityType == 0) then
			(
				ele.SetAttribute "ies_intensity_type" "1" -- ALWAYS CANDELA, INPUT IN LM BUT INTENSITY ALWAYS OUTPUTS CD --
			)
			if (obj.intensityType == 1) then
			(
				ele.SetAttribute "ies_intensity_type" "1" -- ALWAYS CANDELA, INPUT IN LM BUT INTENSITY ALWAYS OUTPUTS CD --
			)
			ele.SetAttribute "ies_intensity_value" (obj.intensity as string)
			ele.SetAttribute "ies_filename" (getAbsolutePath obj.webfile as string)
			ele.SetAttribute "ies_emit_shape" (obj.type as string)
			root2.appendChild ele
			t2 += 1
		)
		if (classOf obj == TargetDirectionallight or classOf obj == Directionallight) then
		(
			LightPos = box length: (10) width: (10) height: (10)
			LightPos.transform = obj.transform
			LightPos.name = "LIGHTPOS_"+obj.name
			
			local ele = xml.CreateElement "light"
			ele.SetAttribute "name"  obj.name
			ele.SetAttribute "vray"  "false"
			ele.SetAttribute "on" (obj.on as string)
			ele.SetAttribute "multiplier" (obj.multiplier as string)
			target = findString (classOf obj as string) "Target"
			if (target != undefined) then
			(
				ele.SetAttribute "target"  "true"
			)
			else
			(
				ele.SetAttribute "target"  "false"
			)
			ele.SetAttribute "hotspot" (obj.hotspot as string)
			root2.appendChild ele
			t2 += 1
		)
		if (classOf obj == targetSpot) then
		(
			LightPos = box length: (10) width: (10) height: (10)
			LightPos.transform = obj.transform
			LightPos.name = "LIGHTPOS_"+obj.name
			
			local ele = xml.CreateElement "light"
			ele.SetAttribute "name"  obj.name
			local type = "Spot"
			ele.SetAttribute "vray"  "false"
			ele.SetAttribute "target"  "true"
			ele.SetAttribute "on" (obj.on as string)
			ele.SetAttribute "multiplier" (obj.multiplier as string)
			root2.appendChild ele
			t2 += 1
		)

		if (classOf obj == freeSpot) then
		(
			LightPos = box length: (10) width: (10) height: (10)
			LightPos.transform = obj.transform
			LightPos.name = "LIGHTPOS_"+obj.name
			
			--messagebox "frespot"
			local ele = xml.CreateElement "light"
			ele.SetAttribute "name"  obj.name
			local type = "Spot"
			ele.SetAttribute "vray"  "false"
			ele.SetAttribute "target"  "true"
			ele.SetAttribute "on" (obj.on as string)
			ele.SetAttribute "multiplier" (obj.multiplier as string)
			root2.appendChild ele
			t2 += 1
		)
		if (classOf obj == VRayLight) then
		(
			LightPos = box length: (0) width: (obj.size0) height: (obj.size1)
			LightPos.transform = obj.transform
			LightPos.name = "LIGHTPOS_"+obj.name
			
			--messagebox obj.name
			local ele = xml.CreateElement "light"
			local type = #("Plane","Dome","Sphere","Mesh","Disc")
			ele.SetAttribute "vray"  "true"
			ele.SetAttribute "name"  obj.name
			ele.SetAttribute "v_type" "area"

			ele.SetAttribute "invisible" (obj.invisible as string)
			ele.SetAttribute "v_area_type" type[obj.type+1]
			ele.SetAttribute "on" (obj.on as string)

			ele.SetAttribute "units" (#("Default(image)","Luminous ower (lm)","Luminance (lm/m?/sr","Radiant Power (W)","Radiance (W/m?/sr")[obj.normalizeColor+1])
			ele.SetAttribute "multiplier" (obj.multiplier as string)
			ele.SetAttribute "color_mode" (#("Color","Temperature")[obj.color_mode+1])
			ele.SetAttribute "color_temperature" (obj.color_temperature as string)
			ele.SetAttribute "color" (color2String obj.color)
			
			ele.SetAttribute "width" (obj.size0 as string)
			ele.SetAttribute "height" (obj.size1 as string)
			
			ele.SetAttribute "v_shadow" (obj.castShadows as string)
			ele.SetAttribute "affect_diffuse" (obj.affect_diffuse as string)
			ele.SetAttribute "affect_specular" (obj.affect_specular as string)
			ele.SetAttribute "affect_reflections" (obj.affect_reflections as string)
			ele.SetAttribute "shadow_subdivs" (obj.subdivs as string)
			ele.SetAttribute "shadow_bias" (obj.ShadowBias as string)
			try ele.SetAttribute ("skylightPortal") (obj.skylightPortal as string) catch ()
			try ele.SetAttribute ("simplePortal") (obj.simplePortal as string) catch ()
			
			try ele.SetAttribute ("textmap_on") (obj.texmap_on as string) catch ()
			try (	ele.appendChild (shader2Element obj.texmap "vraylightlightmap")) catch ( print "zzz")
			
			root2.appendChild ele
			t2 += 1
		)
		if (classOf obj == VRayIES) then
		(
			LightPos = box length: 10 width: 10 height: 10
			LightPos.transform = obj.transform
			LightPos.name = "LIGHTPOS_"+obj.name
			
			local ele = xml.CreateElement "light"
			ele.SetAttribute "vray"  "true"
			ele.SetAttribute "name"  obj.name
			ele.SetAttribute "type" "VRayIES"

			ele.SetAttribute "enabled" (obj.enabled as string)
			ele.SetAttribute "enable_viewport_shading" (obj.enable_viewport_shading as string)
			ele.SetAttribute "show_distribution" (obj.show_distribution as string)
			ele.SetAttribute "targeted" (obj.targeted as string)
			ele.SetAttribute "target_distance" (obj.target_distance as string)
			ele.SetAttribute "ies_file" (getAbsolutePath obj.ies_file as string)
			ele.SetAttribute "rotation_X" (obj.rotation_X as string)
			ele.SetAttribute "rotation_Y" (obj.rotation_Y as string)
			ele.SetAttribute "rotation_Z" (obj.rotation_Z as string)
			ele.SetAttribute "cutoff" (obj.cutoff as string)
			ele.SetAttribute "shadow_bias" (obj.shadow_bias as string)
			ele.SetAttribute "cast_shadows" (obj.cast_shadows as string)
			ele.SetAttribute "affect_diffuse" (obj.affect_diffuse as string)
			ele.SetAttribute "affect_specular" (obj.affect_specular as string)
			ele.SetAttribute "use_light_shape" (#("No","For shadows only","For illumination and shadow")[obj.use_light_shape+1])
			ele.SetAttribute "override_shape" (obj.override_shape as string)
			ele.SetAttribute "shape" (#("point","rectangle","circle","sphere","vertical cylinder","horizontal cylinder length","horizontal cylinder width","elipse length","elipse width","elipsoid length","elipsoid width")[obj.shape+1])
			ele.SetAttribute "height" (obj.height as string)
			ele.SetAttribute "width" (obj.width as string)
			ele.SetAttribute "length" (obj.length as string)
			ele.SetAttribute "diameter" (obj.diameter  as string)
			ele.SetAttribute "shape_subdivs" (obj.shape_subdivs as string)
			ele.SetAttribute "color_mode" (#("Color","Temperature")[obj.color_mode+1])
			ele.SetAttribute "color" (color2String obj.color)
			ele.SetAttribute "color_temperature" (obj.color_temperature as string)
			ele.SetAttribute "power" (obj.power as string)
			ele.SetAttribute "area_speculars" (obj.area_speculars as string)
			ele.SetAttribute "viewport_wire_color" (color2String obj.viewport_wire_color)
			ele.SetAttribute "viewport_wire_color_on" (obj.viewport_wire_color_on as string)
			--ele.SetAttribute "inclExclType" (obj.inclExclType as string)

				
			root2.appendChild ele				
			t2 += 1
		)
		if (classof obj == VRaySun) then
		(
			LightPos = box length: (10) width: (10) height: (10)
			LightPos.transform = obj.transform
			LightPos.name = "LIGHTPOS_"+obj.name
			
			local ele = xml.CreateElement "light"
			ele.SetAttribute "name"  obj.name
			ele.SetAttribute "v_type"  "sun"
			ele.SetAttribute "vray"  "true"
			ele.SetAttribute "target"  (obj.name + ".Target")
			ele.SetAttribute "v_shadow"  "true"
			ele.SetAttribute "enabled" (obj.enabled as string)
			ele.SetAttribute "invisible" (obj.invisible as string)
			ele.SetAttribute "affect_diffuse" (obj.affect_diffuse as string)
			ele.SetAttribute "affect_specular" (obj.affect_specular as string)
			ele.SetAttribute "cast_shadow" (obj.cast_atmospheric_shadows as string)
			ele.SetAttribute "turbidity" (obj.turbidity as string)
			ele.SetAttribute "ozone" (obj.ozone as string)
			ele.SetAttribute "intensity_multiplier" (obj.intensity_multiplier as string)
			ele.SetAttribute "size_multiplier" (obj.size_multiplier as string)
			ele.SetAttribute "sky_model" (obj.sky_model as string)
			ele.SetAttribute "filter_color" (color2String obj.filter_Color)
			ele.SetAttribute "color_mode" (#("filter","direct","override")[obj.color_mode+1])
			ele.SetAttribute "shadow_subdivs" (obj.shadow_subdivs as string)
			ele.SetAttribute "shadow_bias" (obj.shadow_bias as string)
			ele.SetAttribute "photon_emit_radius" (obj.photon_emit_radius as string)
			
			--ele.SetAttribute "focallength" (replacestring (((mathlib.round (obj.focal_length*10))/10.0) as string) ".0d0" "")
			root2.appendChild ele				
			t2 += 1
		)
	)
	local listName = #()
	local rootList = #(root1,root01,root02,root03,root05,root07,root08,root09)
	--Remove Duplicate Material Nodes From Lists
	rootNum = 0
	for xmlRoot in rootList do
	(
		--print ("ROOT "+rootNum as string)
		actualI = 0
		for i = 0 to (xmlRoot.childNodes.count-1) do
		(
			nodeName = xmlRoot.childNodes.itemOf[i].GetAttribute("name")
			--print ("["+i as string+"] = "+nodeName)
		)
		for i = 0 to (xmlRoot.childNodes.count-1) do
		(
			if actualI > xmlRoot.childNodes.count-1 then continue
			stepBackI = false
			nodeName = xmlRoot.childNodes.itemOf[actualI].GetAttribute("name")
			numSame = 0
			actualK = 0
			--print ("        ["+actualI as string+"] = "+nodeName)
			for k = 0 to (xmlRoot.childNodes.count-1) do
			(
				kNodeName = xmlRoot.childNodes.itemOf[actualK].GetAttribute("name")
				--print ("                ["+actualK as string+"] = "+kNodeName)
				if (nodeName == kNodeName) do
				(
					if (numSame>0) do
					(
						--print "                REMOVING"
						xmlRoot.RemoveChild(xmlRoot.childNodes.itemOf[actualK])
						actualK-=1
						stepBackI = true
					)
					numSame +=1
				)
				actualK+=1
			)
			if stepBackI then
			(
				actualI-=1
				stepBackI = false
			)
			actualI+=1
		)
		rootNum +=1
	)
	for obj in geometry do
	(
		try
		(
			if (findItem listName obj.name == 0) then
			(
				local ele = xml.CreateElement "geometry"
				ele.SetAttribute "name"  obj.name
				ele.SetAttribute "wirecolor" (color2String obj.wirecolor)
				
				for proxyObj in proxyList do
				(
					if (obj.name == proxyObj[3]) then
					(
						ele.SetAttribute "vrayproxy" proxyObj[1]
					)
				)
				
				ele = setMatAndModLists obj ele
				root3.appendChild ele				
				append listName obj.name
				t3 += 1
			)
		) catch ()
	)
	global active_cam
	for obj in cameras do
	(
		try
		(
			if (classof obj != Targetobject) then
			(
				local ele = xml.CreateElement "camera"
				ele.SetAttribute "name"  obj.name
				if (active_cam == obj as string) then
					ele.SetAttribute "active" "true"
				else
					ele.SetAttribute "active" "false"
				if (classof obj == Physical) then
				(
					ele.SetAttribute "vray" "false"
					ele.SetAttribute "filmgate" (obj.film_width_mm as string)
					ele.SetAttribute "focallength" (obj.focal_length_mm as string)
					ele.SetAttribute "f-number" (obj.f_number as string)
					userType = obj.shutter_unit_type
					obj.shutter_unit_type = 0
					ele.SetAttribute "shutter_speed" ( (1/obj.shutter_length_seconds) as string )
					obj.shutter_unit_type = userType
				)
				else if (classof obj == VRayPhysicalCamera) then
				(
					ele.SetAttribute "vray" "true"
					ele.SetAttribute "filmgate" (obj.film_width as string)
					ele.SetAttribute "focallength" (obj.focal_length as string)
					ele.SetAttribute "f-number" (obj.f_number as string)
					ele.SetAttribute "shutter_speed" (obj.shutter_speed as string)
					ele.SetAttribute "ISO" (obj.ISO as string)
					ele.SetAttribute "vignetting" (obj.vignetting as string)
					ele.SetAttribute "vignetting_amount" (obj.vignetting_amount as string)
					ele.SetAttribute "fov_enabled" (obj.specify_fov as string)
					ele.SetAttribute "fov_amount" (obj.fov as string)
				)
				else
				(
					ele.SetAttribute "vray" "false"
					--ele.SetAttribute "fov" (replacestring (((mathlib.round (obj.fov*10))/10.0) as string) ".0d0" "")
					ele.SetAttribute "fov" (obj.fov as string)
				)
				root5.appendChild ele				
				t5 += 1
			)
		) catch ()
	)
	for obj in geometry do
	(
		local m = obj.mat
		if (classof m == VRayMtlWrapper) then
			if (m.matteSurface) then 
			(
				local ele = xml.CreateElement "matte_object"
				ele.SetAttribute "name"  obj.name
				root7.appendChild ele
				t7 += 1
			)
	)
	
	root.appendChild root0
	root.appendChild root01
	root.appendChild root02
	root.appendChild root03
	root.appendChild root04
	root.appendChild root05
	root.appendChild root07
	root.appendChild root08
	root.appendChild root09
	root.appendChild root1
	root.appendChild root4
	root.appendChild root41
	
	root.appendChild root20
	root.appendChild root21
	root.appendChild root22
	root.appendChild root23
	
	if (t2>0) then
		root.appendChild root2
	if (t3>0) then
		root.appendChild root3
	
	if (t5>0) then
		root.appendChild root5
	
	if (t6>0) then
		root.appendChild root6
	
	if (t7>0) then
		root.appendChild root7

	xml.appendChild root
	
	saveXML xml
	
	try
	(
		destroydialog progress
	) catch ()
)

function fixDoubleSided obj i =
		(
			if i==0 then
			(
				if classof obj.mat == DoubleSided then
				(
					local t =  obj.mat.name
					obj.mat = obj.mat.material1
					obj.mat.name = t
				)
			)
			else
			(
				if classof obj.mat[i] == DoubleSided then
				(
					local t =  obj.mat[i].name
					obj.mat[i] = obj.mat.material1
					obj.mat[i].name = t
				)
			)
		)
function fixVray2sided obj i =
		(
			if i==0 then
			(
				if classof obj.mat == VRay2SidedMtl then
				(
					local t =  obj.mat.name
					obj.mat = obj.mat[i].frontMtl
					obj.mat.name = t
				)
			)
			else
				if classof obj.mat[i] == VRay2SidedMtl then
				(
					local t =  obj.mat[i].name
					obj.mat[i] = obj.mat[i].frontMtl
					obj.mat[i].name = t
				)
		)

function getOverrideFrontMtl mat =
	(
		local overridetemp = mat
		while classof overridetemp.baseMtl == VRayOverrideMtl do
			overridetemp = overridetemp.baseMtl
		return overridetemp.baseMtl
	)
	function fixVRayOverrideMtl obj i =
	(
		if i==0 then
		(
			if classof obj.mat == VRayOverrideMtl then
			(
				local t =  obj.mat.name
				obj.mat = getOverrideFrontMtl obj.mat
				obj.mat.name = t
			)
		)
		else
			if classof obj.mat[i] == VRayOverrideMtl then
			(
				local t =  obj.mat[i].name
				obj.mat[i] = getOverrideFrontMtl obj.mat[i]
				obj.mat[i].name = t
			)
	)

function iesToCd =
	(
	for objLight in lights do
		   try( 
					if (classof objLight == Target_Light or classof objLight == Target_Rectangle) then
					(
						if (objLight.Distribution == 3) then
							(
								objLight.intensityType = 1
								)
					)
				)catch ()		
	)

function getFrontMtlShellac mat =
	(
		local tempShellac = mat
		while classof tempShellac.shellacMtl1 == Shellac do
			tempShellac = tempShellac.shellacMtl1
		return tempShellac.shellacMtl1
	)

function fixShellac obj i =
	(
		if i==0 then
		(
			if classof obj.mat == Shellac then
			(
				local t =  obj.mat.name
				obj.mat = getFrontMtlShellac obj.mat
				obj.mat.name = t
			)
		)
		else
			if classof obj.mat[i] == Shellac then
			(
				local t =  obj.mat[i].name
				obj.mat[i] = getFrontMtlShellac obj.mat[i]
				obj.mat[i].name = t
			)
	)

function simplifySS2_Car =
	(
		
		local matArr2 = getclassinstances VRayFastSSS2
		local tmpObj2 = box()
	
		for i in matArr2 do
		(
		 --messagebox (i.name as string)
		 tmpObj2.material = i
		 newMat = Standard()
		 newMat.diffusemap =	i.texmap_sss_color
		 newMat.diffuse = i.sub_surface_color
		 newMat.name = i.name
		 replaceInstances (tmpObj2.material) newMat
		)
		
		delete tmpObj2

		matArr3 = getclassinstances VRayCarPaintMtl
		tmpObj3 = box()
		for i in matArr3 do
		(
		 tmpObj3.material = i
		 newMat = Standard()
		 --newMat.diffusemap = i.base_color_shortmap 
		 newMat.diffuse = i.base_color
		 newMat.name = i.name
		 replaceInstances (tmpObj3.material) newMat
		)
		delete tmpObj3
	)

function simplifyShellac =
	(
			max select all

			for obj in selection do
			if classOf obj.mat == Multimaterial then
			(
				for i=1 to obj.mat.count do
				(
					fixShellac obj i
				)
			)
			else
				fixShellac obj 0
	)

function simplifyVrayOverride =
	(
			max select all
			for obj in selection do
			if classOf obj.mat == Multimaterial then
			(
				for i=1 to obj.mat.count do
				(
					fixVRayOverrideMtl obj i
				)
			)
			else
				fixVRayOverrideMtl obj 0
	)
function simplifyDoubleSidedForExport = 
	(
			max select all
			for obj in selection do
				if classOf obj.mat == Multimaterial then
				(
					for i=1 to obj.mat.count do
					(
						fixDoubleSided obj i
					)
				)
				else
					fixDoubleSided obj 0
	)
function simplifyVray2Sided =
	(
			max select all
			for obj in selection do
				if classOf obj.mat == Multimaterial then
				(
					for i=1 to obj.mat.count do
					(
						fixVray2sided obj i
					)
				)
				else
					fixVray2sided obj 0
	)
	
function fixBlendToStd =
	(
		matArray = getClassInstances Blend
		tmpObj = box()
		for i in matArray do
		(
		tmpObj.material = i
		tmpName = i.name
		newMat = i.map1
		replaceInstances tmpObj.material newMat
		tmpObj.material.name = tmpName
		)
		delete tmpObj
	)

function vraytostd =
	(
	if (vray != undefined) then 
		(
			matArr = getclassinstances vraymtl
			local tmpObj = box()
			for i in matArr do
				(
				 tmpObj.material = i
				 newMat = Standard()
				 newMat.diffusemap = i.texmap_diffuse
				 newMat.diffuse = i.diffuse
				 newMat.name = i.name
				 replaceInstances (tmpObj.material) newMat
				)
		)	
	delete tmpObj
	)

function MakeUniqueBlue =
	(
		global makeDifferent = 0
		matTypes = material.classes
		matArray = #()
		for cmt in matTypes do
		(
			tmpArr = getClassInstances cmt
			matArray = matArray + tmpArr
		)

	local o = box()

	if (vray != undefined) then 
	(	
		local matArr2 = getclassinstances VRayFastSSS2
	
		for i in matArr2 do
		(
		local temp = i.name
		newMat = Standard()
		ss2ssColor = i.sub_surface_color
		--messagebox (ss2ssColor as string)

		--replaceInstances o.material newMat
		o.material = newMat					
		o.material.diffuse = ss2ssColor --color 0 0 makeDifferent
		o.material.name = temp
		)
	)
		for cm in matArray do 
		(
			o.material = cm
			--print o.material.name
			--print (classof o.material)
			if classof o.material == Multimaterial then 
			(
				for m = 1 to o.material.numsubs do
				(
					if (isNeed2Standard o.material[m]) then
					(	
					try(
						
						if (o.material.diffusemap == undefined or o.material.texmap_diffuse == undefined) then
								(
								local temp = o.material[m].name
								newMat = Standard()
								--replaceInstances o.material[m] newMat
								o.material[m] = newMat
								o.material[m].diffuse = color 0 0 makeDifferent
								o.material[m].name = temp
								makeDifferent +=1
								)
						)catch()
					)
					else
						try
						(
							o.material[m].shaderType = 1
						) catch ()
				)
			)
			else
			(
				if true then
				(	
					global temp = o.material.name
					if (classof o.material == VrayBlendMtl) or (classof o.material == Blend) then
					(
						--print ("MakeDifferent = "+temp)
					)
					

					if (classof o.material == VRayFastSSS2) then
					(
								(
								newMat = Standard()
								ss2ssColor = o.material.sub_surface_color
								--replaceInstances o.material newMat
								o.material = newMat					
								o.material.diffuse = ss2ssColor --color 0 0 makeDifferent
								o.material.name = temp

								)
					)
					
					try(
						if (o.material.diffusemap == undefined or o.material.texmap_diffuse == undefined) then
								(
								newMat = Standard()
								--replaceInstances o.material newMat
								o.material = newMat					
								o.material.diffuse = color 0 0 makeDifferent
								o.material.name = temp
								makeDifferent +=1
								)
						)catch()

				)
			)
		)
		delete o
		listmat = collectAllSingleMaterial()
		global listj =#{}
		for i = 1 to listmat.count-1 do
		(
			global val = 0.01
			for j=i+1 to listmat.count do
				if (listj[i] == false and listj[j]==false ) then
				(
					if (listmat[i] == listmat[j]) then
						listj += #{j}
				)
		)
	)
	
function shapeToPoly =
	(
			max select none
			select shapes
			macros.run "Modifier Stack" "Convert_to_Poly"
			max select none
	)
function deleteEmptyGeo =
	(
		max select none
		selCount = 0
		for obj in geometry do
			(
				try
				(
					if (obj.numFaces == 0) do
					(
					selectMore obj
					selCount = selCount+1
					)--end if
					
				)--end try
				catch ()--end catch
			
			)--end for
		max delete
		--messagebox "done"
	)

function CCtoBitmap =
(
	if (classof environmentMap == Color_Correction) then
	(
		ccMap = environmentMap.map
		environmentMap = ccMap
	)
)

function backgroundStdfix =
	(
		vr = renderers.current
		if (findString (toLower (vr as string)) "v_ray" == 1) then
			(
				if vr.environment_gi_map == undefined then vr.environment_gi_map = environmentMap
			)
	)

function ProxyToPoly =
	(
		--clearListener()
		proxyList = #()
		deleteList = #()
		
		for obj in geometry do
		(
			if (classof obj==VRayProxy) do
			(
				alreadyFound = false
				foundCount = 0
				masterName = ""
				for proxy in proxyList do
				(
					if (proxy[1]==obj.filename) then
					(
						alreadyFound = true
						foundCount += 1
						masterName = proxy[2]
					)
				)
				if (alreadyFound==false) then
				(
					--print ("Found First Instance of Proxy ( "+obj.filename+" )")
					-- Store Master Proxy Object Name and Convert To Poly
					renameName = "PROXYM_"+obj.name
					append proxyList #(obj.filename,obj.name,renameName)
					obj.display = 4
					obj.name = renameName
					ConvertTo obj Editable_Poly
				)
				else
				(
					--print ("Found Another ( "+obj.filename+" )")
					renameName = "PROXYS_"+masterName+"_"+(foundCount as string)
					append proxyList #(obj.filename,obj.name,renameName)
					tempCube = Box()
					tempCube.transform = obj.transform
					tempCube.name =renameName					
					append deleteList obj
				)
			)
		)
		for ob in deleteList do
		(
			delete ob
		)
	)

function Export01 option =
	(
		local selObj = selection as array
		holdMaxFile()
		mayaNameFixes() -- Maya Names fixes to avoid spaces etc!
		vrayNextGPUfix()	
		vrayRTfix()
		--isHavingWeirCharacter
		
		local newFileName = "___EXPORTED"
		local tempPath=sysInfo.tempdir 
		-- Save current scene state
		
		
		doPatches()
		
		local listmat = collectAllSingleMaterial()
		for m in listmat do
		(
			try (
				if (m.diffuse == color 0 0 0) then
					m.diffuse = color 1 0 0 
			)
			catch()
		)	
			
		if (count_cam==0) then
			try (
				if ((maxVersion() as array)[1] >= 18000) then
					--macros.run "Lights and Cameras" "PhysicalCamera_CreateFromView"
					macros.run "Lights and Cameras" "StandardCamera_CreateFromView"
				else
					macros.run "Lights and Cameras" "Camera_CreateFromView"
				global newcam = getActiveCamera()
				newcam.name = "TempCam"
				active_cam = newcam
				if ((maxVersion() as array)[1] >= 18000) then
					newcam.targeted = off
				else
					newcam.type = #free
				
			) catch ()	
		
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************

		if option==1 then --DEFAULT"
		(
			max create mode
			ProxyToPoly()
			fixVrayLightsScale()
			--deleteEmptyGeo()
			rXMLExport.theProgressbar.value = 5
			CCtoBitmap()
			shapeToPoly()
			iesToCd()
			
			if (vray != undefined) then simplifySS2_Car()
			
			removeCC()
			
			if (vray != undefined) then backgroundStdfix()			
				rXMLExport.theProgressbar.value = 10
			if (vray != undefined) then c01_Simplifier()
				windows.processPostedMessages()
				rXMLExport.theProgressbar.value = 20
			if (vray != undefined) then removeDisplacements()
				windows.processPostedMessages()
				rXMLExport.theProgressbar.value = 30
			if (vray != undefined) then fixBlendToStd()
				windows.processPostedMessages()
				rXMLExport.theProgressbar.value = 40
				--windows.processPostedMessages()
				--rXMLExport.theProgressbar.value = 45
			if (vray != undefined) then simplifyVrayOverride()
				windows.processPostedMessages()
				rXMLExport.theProgressbar.value = 50
			if (vray != undefined) then simplifyShellac()
				windows.processPostedMessages()
				rXMLExport.theProgressbar.value = 55
				windows.processPostedMessages()
				rXMLExport.theProgressbar.value = 60

			simplifyVRay2SidedMtl()
			simplifyMAPS()
			fixGroupMirror()
				
			--if (vray != undefined) then ShadersSimple()
			-- 	windows.processPostedMessages()
			-- 	rXMLExport.theProgressbar.value = 65
			
			--c02_BakeShaderAll()
			-- 	windows.processPostedMessages()
			-- 	rXMLExport.theProgressbar.value = 70
			
			Export02() --make xml
			
			-- 	rXMLExport.theProgressbar.value = 80
			-- 	windows.processPostedMessages()
			
			MakeUniqueBlue()
				rXMLExport.theProgressbar.value = 85
				windows.processPostedMessages()
				rXMLExport.theProgressbar.value = 90
			
			simplifyDoubleSidedForExport()
			
			if (vray != undefined) then vraytostd()
			
			enableSceneRedraw()

			--max reset file
		)

		if option==2 then --ACCURACY
		(

			max create mode
			ProxyToPoly()
			fixVrayLightsScale()
			deleteEmptyGeo()

			simplifyVRay2SidedMtl()
			simplifyMAPS()
			fixGroupMirror()

			Export02() --make xml

			simp_MakeUnique() --make blue unique materials
		
		)

		if option==3 then --COMPATIBILITY
		(	

			disableSceneRedraw()
			max create mode
			ProxyToPoly()
			fixVrayLightsScale()
			deleteEmptyGeo()
			select lights
			max delete
			CCtoBitmap()
			shapeToPoly()
			simplifySS2_Car()
			removeCC()

			environmentMap = undefined
			if (vray != undefined) then c01_Simplifier()
			if (vray != undefined) then removeDisplacements()
			if (vray != undefined) then fixBlendToStd()
			if (vray != undefined) then simplifyVray2Sided()
			if (vray != undefined) then simplifyVrayOverride()
			if (vray != undefined) then simplifyShellac()
			if (vray != undefined) then	simplifySS2_Car()
			if (vray != undefined) then ShadersSimple()

			--try (select none) catch()
			c02_BakeShaderAll()
			--if (vray != undefined) then c03_vrtostd()

			simplifyVRay2SidedMtl()
			simplifyMAPS()
			fixGroupMirror()

			Export02() --make xml
			MakeUniqueBlue()
			enableSceneRedraw()
		)
		
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************
		--********************************************************************************************************

		windows.processPostedMessages()
		actionMan.executeAction 0 "40807" ---
		--actionMan.executeAction 0 "63545"  -- Views: Viewport Materials Display as Shaded with Maps
		windows.processPostedMessages()
		FBXExporterSetParam "FileVersion" "FBX201400"
		FBXExporterSetParam "Triangulate"  false
		windows.processPostedMessages()
		rXMLExport.theProgressbar.value = 100
				
		for cam in cameras do
		(
			if (findstring cam.name "target" == undefined) then
			(
				tempBox = Point()
				tempBox.name = "CAMPOS_"+cam.name
				tempBox.transform = cam.transform
			)
		)
			
		local selected = (rXMLExport.exportType.state == 2)
		---export selected query
		/*
		if (selObj.count > 0) then
			selected = queryBox "Some Object is selected, choose:\nYES - Exports selected object only\nNO - Exports whole scene"  title:"Export to fbx"
		*/
		
		if (selected) then 
		(
			select selObj

		)
		
		exportFile (userPath+"\\3dm2b.fbx") #noPrompt selectedOnly:selected using:FBXEXP
		return true
	)
	
function CollapseMeshModifiers=
	(
		--max modify mode
		for obj in geometry do
		(
			for index = obj.modifiers.count to 1 by -1 do
			(
				--Search for SymmetryModifiers
				if (((classOf obj.modifiers[index]) == Symmetry)) then
				(
					--print ("COLLAPSING = "+obj.name)
					--modPanel.setCurrentObject obj.modifiers[index]
					undo off(
						maxOps.CollapseNodeTo obj (index) false
					)
				)
			)
			
		)
		
	)

function grabViewPortSmall thumbPath=
	(
		print thumbPath
		try(
			makeDir userPath
		) catch()
		--saveToPath = @"G:\\Users\\Marcelo Luis Bruno\\Documents\\TEMP3D\\" --CAMBIARRRR CHELO

		grab_viewpBMP = gw.getViewportDib()
		target = bitmap 180 120
		local w = grab_viewpBMP.width
		local h = grab_viewpBMP.height
		local tempBMP
		local hh = 0
		local ww = 0
		if target.width*1.0/target.height > w*1.0/h then
		(
			h = target.height*w/target.width
			hh = (grab_viewpBMP.height - h)/2
		)
		else
		(
			w = target.width*h/target.height
			ww = (grab_viewpBMP.width - w)/2
		)
		tempBMP = bitmap w h
		pasteBitmap grab_viewpBMP tempBMP (box2 ww hh (w+ww) (h+hh)) [0,0] 

		copy tempBMP target
		target.filename = (thumbPath + "\\3dm2m.jpg")
		print hh
		print ww

		save target
		close target
		close grab_viewpBMP
		target = undefined
		grab_viewpBMP = undefined
		freeSceneBitmaps()
	)

function StartExport option thumbPath =
	(
		--clearListener()
		
		actionMan.executeAction 0 "40182"
		makeDir userPath
		
		units.SystemScale = 1.0
		units.SystemType = #Centimeters
		
		
		CollapseMeshModifiers()


		
		Export_FixObjectName()
		Export_FixMaterialName()
		Export_FixTextureName()

		Export01 option
		--if option== 2 then
		--	(
		--	Export02()
		--	)
		
		for obj in cameras do
		(
			if (classof obj != Targetobject) then
			(
				if (active_cam == obj as string) then
				(
					select obj
					actionMan.executeAction 0 "40068"  -- Views: Camera View
				)
			)
		)
		function toFilename file i =
		(
			if (i<10) then 
				return (file+"_00"+i as string)
			else
				if (i<100) then 
					return (file+"_0"+i as string)
				else
					return (file+"_"+i as string)
		)
		
		fetchMaxFile quiet:true

		
		
		---messagebox "Done. Now you can pick the scene from C4D" title:""
		return true
		--turn off log file
		local filename = getfilenamefile maxfilename
		local ii = 1
		local fullname = userPath+"\\"+(toFilename filename ii)+".log"
		while (doesFileExist fullname) do
		(
			ii += 1
			fullname = userPath+"\\"+(toFilename filename ii)+".log"
		)
		local f = dotnetobject "System.IO.StreamWriter" fullname
		local t = getLocalTime()
		f.WriteLine (t[1] as string +"-"+t[2] as string+"-"+t[4] as string+"  "+t[5] as string+":"+t[6] as string+":"+t[7] as string+"."+t[8] as string)
		f.WriteLine "The following elements should be recorded as part of the process:"
		f.WriteLine "Any components within a scene that have naming issues upon export"
		f.WriteLine "All components successfully exported"
		f.WriteLine "All bitmap textures successfully exported"
		f.WriteLine "All components (lights / cameras) successfully imported"
		f.close()
	)

disableSceneRedraw()
global tGamma = IDisplayGamma.colorCorrectionMode
IDisplayGamma.colorCorrectionMode = #none
	
try(destroyDialog rXMLExport )catch()
try(destroyDialog rExportWaiting )catch()

rollout rExportWaiting  "Status" height:30 width:342
(
	label lbText "Please Wait.... collecting files"
)
rollout rXMLExport  "MaxToBlender v2.0f" height:230 width:342
(
	local b = openBitMap imagepath
	imgTag imgLogo "" pos:[0,0] transparent:[50,255,50] style:#bmp_center bitmap:b align:#center height:88
	
	group "Conversion mode:"
	(
	radiobuttons exportType labels:#("Full Scene", "Only Selected") default:1 across:3
	checkbutton chOp2 "Compatibility" checked:false width:90  height:30 pos:[135,110] -- across:2 --tooltip:"Opens setup panels"
	checkbutton chOp0 "Best" width:90 height:30 checked:true pos:[135+90+2,110] --tooltip:"Opens setup panels"
	-- button bntSettings "..." width:30 height:30 checked:false pos:[110+(90*2)+(2*2),110] --tooltip:"Opens setup panels"	
	)
	-- edittext theEdittext "Temp Path:" width:229 enabled:true across:3
	-- button btChange "..." width:30 height:15 pos:[249,159-5]
	-- button btDefault "Default" width:50 height:15 pos:[279,159-5]
	progressbar theProgressbar "Progressbar:" height:10 value:0 color:[255,118,10]
	--button btnZip "Pack as .3ta..." width:115 height:35 offset:[-15,0] across:2
	button btExpStart "Auto-Export" width:190 height:35 --offset:[-20,0]
	label theLabel "(c) 2019 3DtoAll. All rights reserved." enabled:false 
	
	on btDefault pressed do
	(
		theEdittext.text = userDefaultPath
	)
	on rXMLExport open do
	(
		try(theEdittext.text = userPath)catch()
	)
	on btnGrab pressed do
	(
		grabViewPortSmall edittext.text
	)
	on chOp0 changed state do
	(
		--messagebox scriptpath
		--chOp1.checked = false
		chOp2.checked = false
		chOp0.checked = true
	)
	on chOp1 changed state do
	(
		chOp0.checked = false
		chOp2.checked = false
		--chOp1.checked = true
	)
	on chOp2 changed state do
	(
		chOp0.checked = false
		--chOp1.checked = false
		chOp2.checked = true
	)
	fn GetBitmapTextures theObjects =
	(
		local texMaps = #()
		for obj in theObjects do
		(
			join texMaps (getClassInstances bitmapTexture target:obj asTrackViewPick:off)
		)
		makeUniqueArray texMaps
		return texMaps
	)	
	on btnZip pressed do
	(
		if (rXMLExport.exportType.state == 2 and (selection as array).count == 0) then
		(
			messagebox "Selection mode selected, but nothing selected"		
			return false
		)
		
		isZip = true
		local filename = getSaveFileName caption:"3ta file" types:"3ta file(*.3ta)|*.3ta"
		local filepath = ""
		local cont = true
		if filename == undefined then 
			cont = false

		if cont then
		(
			try(destroyDialog rExportWaiting )catch()
			createDialog rExportWaiting
			if getFileNameType filename != ".3ta" then
				filename += ".3ta"
			filepath = (getFilenamePath filename) + "\\ziptemp"
		
			makeDir filepath
			makeDir (filepath+"\\tex")
			if doesFileExist filename then
			(
				deleteFile filename
			)	
			for f in (getFiles (filepath+"\\*.*")) do
				deleteFile f			
			print filepath
			print filename
			userPath = filepath
				

			local sel = selection as array
			if (rXMLExport.exportType.state == 2 and (selection as array).count > 0) then
			(
				max hide inv
			)
			max select none
			redrawViews() 	 
			grabViewPortSmall filepath
			max unhide all
			select sel			
			
			StartExport 1 filepath
			if xencrypt == 1 then
			(
				local file = openFile (userPath +"\\3dm2m.xml")
				local file1 = createFile (userPath +"\\material.xm_")
				while not eof file do 
				(
					r=  readLine file
					for i=1 to r.count do
						r[i] = (bit.IntasChar (bit.charAsInt r[i] + xvalue))[1]
					print r to:file1
				)
				seek file 0
				close file
				close file1		
				deleteFile (userPath +"\\material.xml")		
			)
			local texmaps = (GetBitmapTextures $*)
			for texMap in texMaps do 
			(
				copyFile (mapPaths.getFullFilePath texMap.filename) (filepath+"\\tex\\"+ (getFileNameFile texMap.filename)+(getFileNameType texMap.filename))
			)				
				
			local z = zip()
			z.sourceFolderPath =filepath
			z.targetFolderPath = getFileNamePath filename
			z.zipFileName = getFilenameFile filename
			z.fn_zipFiles sourceFolderPath:z.sourceFolderPath targetFolderPath:z.targetFolderPath zipFileName:z.zipFileName

			deleteFile (z.targetFolderPath+"\\"+ z.zipFileName +".tmp")
			for f in (getFiles (filepath+"\\*.*")) do
				deleteFile f
			for d in (getDirectories (filepath+"\\*")) do
			(
				for f in (getFiles (d+"\\*.*")) do
				(
					deleteFile f
				)
				(dotNetClass "System.IO.Directory").Delete(d)
			)			
			(dotNetClass "System.IO.Directory").Delete(filepath)
			try(destroyDialog rExportWaiting )catch()
			messagebox "3TA Pack Complete." title:""		
		)
		isZip = false
	)
	on btExpStart pressed do
	(	
		if (rXMLExport.exportType.state == 2 and (selection as array).count == 0) then
		(
			messagebox "Selection mode selected, but nothing selected"		
			return false
		)
		
		local sel = selection as array
		if (rXMLExport.exportType.state == 2 and (selection as array).count > 0) then
		(
			max hide inv
		)
		max select none
		redrawViews() 	 
		grabViewPortSmall targetPath
		max unhide all
		select sel
		
		isZip = false
		--rXMLExport.btExpStart.enabled = false
		userPath = targetPath
		try(data.itemof[0].attributes.Itemof["path"].value = userPath)catch(print("path attributes skipped"))
		
		try
		xmlDoc.save configpath
		catch
		(
		print("  ERROR: Can't Access config.xml\n\n  If problems in export you can try running 3ds Max in admin mode. \n  Or go to the 3dsmax\scripts folder and in MaxToBlender folder properties \n  UnCheck 'Read-Only' for the folder and files.")
		)
		
		if chOp0.checked == true then StartExport 1 targetPath
		--if chOp1.checked == true then StartExport 2 theEdittext.text
		if chOp2.checked == true then StartExport 3 targetPath
			
		if xencrypt == 1 then
		(
			local f1 = dotNetObject "System.IO.StreamWriter" (userPath +"\\material.xm_")
			local f = openFile (userPath +"\\material.xml") mode:"rt"
			while not eof f do
			(
				r=  readLine f
				for i=1 to r.count do
					r[i] = (bit.IntasChar (mod (bit.charAsInt r[i] + xvalue) 256))[1]
				f1.WriteLine r
			)
			close f
			f1.close()
		)		
		--
		--deleteFile (userPath +"\\material.xml")
		deleteFile (userPath +"\\material.xm_")
		
		
		
		messagebox "Done. Now you can pick the scene from Blender" title:""
		rXMLExport.theProgressbar.value = 0		
		--try(destroyDialog rXMLExport )catch()	
	)
	on btChange pressed do
	(
		local folder = getSavePath()
		if (folder !=undefined) then
			theEdittext.text = folder
	)
	/*on btOption2 pressed do
	(
		StartExport 2
		try(destroyDialog rXMLExport )catch()	
	)
	on btOption3 pressed do
	(
		StartExport 3
		try(destroyDialog rXMLExport )catch()	
	)	*/
)

-- createDialog rXMLExport

IDisplayGamma.colorCorrectionMode = tGamma
enableSceneRedraw()

function startRollout =
(
	--createDialog rAutoCAT style:#(#style_border, #style_sysmenu, #style_toolwindow)
	try destroyDialog rXMLExport catch()
	createDialog rXMLExport

	IDisplayGamma.colorCorrectionMode = tGamma
	enableSceneRedraw()

)



function checkMaxVersion limitVersion =
(
	caca = GetFileVersion (getDir #maxRoot + "\\3dsmax.exe")
	maxVer = caca[1] + caca[2]
	currentMaxVer = maxVer as Integer
	currentMaxVer -= 2
	currentMaxVer += 2000
	
	print currentMaxVer
	print limitVersion

	--Here the max version allowed to run...
	if  currentMaxVer >= limitVersion  then
	(
		messagebox "Current 3ds Max is not supported in this version. \n\nTo get updates or support check:\nwww.3dtoall.com" title:"Warning: No Supported"
		return 0
	)
	else
	(
		return 1
	)
)



	if checkMaxVersion 2050  == true or checkMaxVersion 2050  == 1 then
	(
		startRollout()
	)

