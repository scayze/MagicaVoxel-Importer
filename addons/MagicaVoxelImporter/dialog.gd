tool
extends ConfirmationDialog

signal confirm_import( vox_path, target_path )

var vbox
var vox_edit
var _target_edit
var _base_control

var _proxy = EditorImportPlugin.new()

func validate_source_path( abs_path ):
	return _proxy.validate_source_path( abs_path )

func _init( base_control ):
	_base_control = base_control
	set_title( "MagicaVoxels import" )
	get_ok().set_text( "Import" )
	connect( 'confirmed', self, '_on_confirmed' )
	
	vbox = VBoxContainer.new()
	add_child( vbox )
#	set_child_rect( vbox ) # not exposed, so:
	var label = get_label()
	for i in range(4):
		vbox.set_anchor_and_margin( i, label.get_anchor(i), label.get_margin(i) )
	label.hide()
	
	add_header( "Source" )
	
	var path_edit = {}
	path_edit.label = Label.new()
	path_edit.label.set_text( "Voxels:" )
	vbox.add_child( path_edit.label )
	
	var margin_container = MarginContainer.new()
	vbox.add_child( margin_container )
	path_edit.hb = HBoxContainer.new()
	margin_container.add_child( path_edit.hb )
	
	path_edit.edit = LineEdit.new()
	path_edit.edit.set_h_size_flags( SIZE_EXPAND_FILL )
	path_edit.hb.add_child( path_edit.edit )
	
	path_edit.button = Button.new()
	path_edit.button.set_text( " .. " )
	path_edit.hb.add_child( path_edit.button )
	
	path_edit.dialog = EditorFileDialog.new()
	path_edit.button.connect( 'pressed', path_edit.dialog, 'popup_centered_ratio' )
	
	path_edit.dialog.add_filter( "*.vox;MagicaVoxels" )
	path_edit.dialog.set_mode( EditorFileDialog.MODE_OPEN_FILE )
	path_edit.dialog.set_access(EditorFileDialog.ACCESS_FILESYSTEM)
	path_edit.dialog.connect( 'file_selected', self, '_set_validated_path', [path_edit.edit] )
	_base_control.add_child( path_edit.dialog )
	
	vox_edit = path_edit.edit
	
	var seperator = HSeparator.new()
	seperator.set_opacity( 0 )
	vbox.add_child( seperator )
	add_header( "Target" )
	
	var target_edit = {}
	target_edit.label = Label.new()
	target_edit.label.set_text( "Voxels:" )
	vbox.add_child( target_edit.label )
	
	var margin_container_2 = MarginContainer.new()
	vbox.add_child( margin_container_2 )
	target_edit.hb = HBoxContainer.new()
	margin_container_2.add_child( target_edit.hb )
	
	target_edit.edit = LineEdit.new()
	target_edit.edit.set_h_size_flags( SIZE_EXPAND_FILL )
	target_edit.hb.add_child( target_edit.edit )
	
	target_edit.button = Button.new()
	target_edit.button.set_text( " .. " )
	target_edit.hb.add_child( target_edit.button )
	
	target_edit.dialog = EditorFileDialog.new()
	target_edit.button.connect( 'pressed', target_edit.dialog, 'popup_centered_ratio' )
	
	target_edit.dialog.set_mode( EditorFileDialog.MODE_OPEN_DIR )
	#target_edit.dialog.connect( 'file_selected', self, '_set_validated_path', [target_edit.edit] )
	target_edit.dialog.connect( 'dir_selected', target_edit.edit, 'set_text' )
	_base_control.add_child( target_edit.dialog )
	_target_edit = target_edit.edit

func add_header( name ):
	var hb = HBoxContainer.new()
	vbox.add_child( hb )
	var seperator = HSeparator.new()
	seperator.set_h_size_flags( SIZE_EXPAND_FILL )
	hb.add_child( seperator )
	var label = Label.new()
	label.set_text( name )
	hb.add_child( label )
	seperator = seperator.duplicate()
	hb.add_child( seperator )

func _set_validated_path( path, edit ):
	edit.set_text( validate_source_path( path ) )

func _on_confirmed():
	emit_signal( 'confirm_import', vox_edit.get_text(), _target_edit.get_text() )

func setup( source_path, target_path ):
	if source_path != null:
		_set_validated_path( source_path, vox_edit )
	if target_path != null:
		_target_edit.set_text( target_path )
