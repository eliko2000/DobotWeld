--[[
重要说明：
1. 此处为备份说明，目前控制器的RPC机制还在完善中，为了兼容2种rpc方式，故此保留2种实现方式。
2. `MainApplication.rpcAPIServer()`与`httpAPIServer()|userAPIServer()`都是提供RPC服务的，但是二者不能同时使用。
3. 选择不同的方式时，要在`MainApplication.run()`中切换对应的方式，同时也要在`DobotWelderRPC.lua`中切换对应的方式。
4. 后期控制器的rpc机制稳定后再删除遗留的代码。
]]--

--[[
package.loaded["rpc.MyDobotWelderRPC"] = nil
require("rpc.MyDobotWelderRPC")
]]--

package.loaded["rpc.LuacDobotWelderRPC"] = nil
require("rpc.LuacDobotWelderRPC")