extends Control

onready var trackBox = $Panel/VBox/TrackBox
onready var calculatingBox = $Panel/VBox/CalculatingBox
onready var carsBox = $Panel/VBox/CarsVBox
onready var controller = $"../.."
onready var trackOption = $"Panel/VBox/TrackBox/TrackOption"
onready var pauseButton = $"Panel/VBox/CalculatingBox/HBoxContainer2/PauseButton"

func onPauseButton():
	controller.togglePaused()
	pauseButton.text = 'Retomar' if controller.isPaused() else 'Pausar'

func setTrackOptions(array):
	for i in range(array.size()):
		trackOption.add_item(array[i],i)

func changePanelState(state):
	match (state):
		0:
			trackBox.visible = true
			carsBox.visible = false
			calculatingBox.visible = false
		1:
			trackBox.visible = false
			carsBox.visible = false
			calculatingBox.visible = true
		2:
			trackBox.visible = false
			carsBox.visible = true
			calculatingBox.visible = false
