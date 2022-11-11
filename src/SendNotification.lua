return function(title, text, buttonText, duration)
	game.StarterGui:SetCore("SendNotification", 
		{
			Title = title, 
			Text = text, 
			Icon = "rbxassetid://4688867958", 
			Duration = duration, 
			Button1 = buttonText
		}
	)
end