// What wulin_master's template writes for a host with these components:
// wulin_master first, because the others attach to its globals at load time.
import "../../vendor/gems/wulin_master/app/javascript/wulin_master.esm.js"
import "../../vendor/gems/wulin_permits/app/javascript/wulin_permits.esm.js"
// The agent's prebuilt bundle, from this repository.
import "../../../../app/assets/builds/wulin_agent.js"
