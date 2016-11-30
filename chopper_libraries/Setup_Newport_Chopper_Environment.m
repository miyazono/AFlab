cmd_lib_path = 'C:\Program Files\New Focus\New Focus Chopper Application\BinCmdLib3502.dll';
lib_wrapper_path = 'C:\Program Files\New Focus\New Focus Chopper Application\Bin\NpChopperLibWrap.dll';

cmd_class = NET.addAssembly(cmd_lib_path);
lib_class = NET.addAssembly(lib_wrapper_path);