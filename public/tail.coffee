[_, _, app, host] = "#{document.location.pathname}".split '/'
console.log app, host


socket = io.connect()

socket.on 'tail', (data) ->
	lines = data.data.split "\n"
	for line in lines
		$('#logs').append $ """<div class="span12 group"><span class="host">#{data.host}</span><span>#{line}</span></div>"""


	console.log data
socket.emit 'tail',
	name: app
	host: host