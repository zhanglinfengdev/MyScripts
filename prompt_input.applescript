

on run argv
    set allUserInputs to ""
    
    set title to item 1 of argv
    -- 遍历所有传递给脚本的参数
    repeat with i from 2 to count of argv
        -- 获取当前参数
        set currentArg to item i of argv
        -- 弹出允许多行输入的对话框
        -- set userInput to the text returned of (display dialog "请输入参数 " & i & " (" & currentArg & "):" default answer "" buttons {"Cancel", "OK"} default button "OK" with title "多行输入框")
        set userInput to the text returned of (display dialog "" & currentArg default answer "" buttons {"Cancel", "OK"} default button "OK" with title "" & title)
        -- 将用户输入追加到allUserInputs变量
        set allUserInputs to allUserInputs & userInput & "\n"
    end repeat
    
    -- 返回所有用户输入的拼接字符串
    return allUserInputs
end run

