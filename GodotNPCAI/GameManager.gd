extends Node

var api_key : String = "replace with API key"
var url : String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=" + api_key
var temperature : float = 0.5
var max_tokens : int = 1024
var headers = ["Content-type: application/json"]
var contents = []
var request : HTTPRequest

@onready var dialogue_box = get_node("/root/Main/CanvasLayer/DialogueBox")
var current_npc
@export_multiline var dialogue_rules : String

signal on_player_talk
signal on_npc_talk (npc_dialogue)

func _ready ():
	request = HTTPRequest.new()
	add_child(request)
	request.connect("request_completed", _on_request_completed)
	
# called when we want to talk to the AI
func dialogue_request (player_dialogue):
	var prompt = player_dialogue
	
	if len(contents) == 0:
		var header_prompt = "Act as a " + current_npc.physical_description + " in a fantasy RPG. "
		header_prompt += "As a character, you are " + current_npc.personality + ". "
		header_prompt += "Your location is " + current_npc.location_description + ". "
		header_prompt += "You have secret knowledge  that you will not speak about unless asked by me: " + current_npc.secret_knowledge + ". "
		
		prompt = dialogue_rules + "\n" + header_prompt + "\nWhat is your first line of dialogue?"
	
	contents.append({
		"role": "user",
		"parts": [{
			"text": prompt
		}]
	})
	
	on_player_talk.emit()

	# create the request body
	var body = JSON.new().stringify({
		"contents": contents,
		"safetySettings": [
			{
				"category": "HARM_CATEGORY_DANGEROUS_CONTENT",
				"threshold": "BLOCK_NONE"
			},
			{
				"category": "HARM_CATEGORY_HARASSMENT",
				"threshold": "BLOCK_NONE",
			},
			{
				"category": "HARM_CATEGORY_HATE_SPEECH",
				"threshold": "BLOCK_NONE",
			},
			{
				"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
				"threshold": "BLOCK_NONE",
			}
		],
		"generationConfig": {
			"temperature": temperature,
			"maxOutputTokens": max_tokens,
		}
	})

	# send the request to the AI server
	var send_request = request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	# if there was a problem, make it known
	if send_request != OK:
		print("There was an error!")

# called when we have received a response from the server
func _on_request_completed (result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	var message = response["candidates"][0]["content"]["parts"][0]["text"]
	
	contents.append({
		"role": "model",
		"parts": [{
			"text": message
		}]
	})

	on_npc_talk.emit(message)

# called when we begin talking with an NPC
func enter_new_dialogue (npc):
	current_npc = npc
	contents = []
	dialogue_box.visible = true
	dialogue_box.initialize_with_npc(npc)
	dialogue_request("")

# called when we stop talking with an NPC
func exit_dialogue ():
	current_npc = null
	contents = []
	dialogue_box.visible = false

# are we currently talking? True or False
func is_dialogue_active ():
	return dialogue_box.visible
