--
-- cas-tls.lua
--
-- CAS Vault Integration and TLS Certificate Management
-- July 2017 - Initial implementation.
-- January 2018 - Refactored logging to make use of CAS Configuration logging facility.
-- February 2018 - Integrated with CAS Configuration cas.lock function.
--

log.info( 'Lua: cas-tls.lua begins' )

--
-- Global variables
--

--
-- Establish global variables that are related to, and which depend
-- upon, the values of tenant and instance.
--
tenant_name = cas.tenantid
if ( tenant_name == nil or string.len(tenant_name) <= 0 or tenant_name == 'uaa' ) then
    -- Note that we intentionally map a cas.tenantid of 'uaa' to a
    -- tenant_name of 'shared'.  This done for two reasons:
    -- (1.) So that the correct paths to Consul KVs are used.
    -- (2.) So that our arguments to cas-tls.sh are copacetic.
    tenant_name = 'shared'
end

current_dir = nil
config_loc = nil
deployment_instance = nil
current_dir = debug.getinfo(1).source:match('@?(.*/)')  -- Lua get directory of currently executing Lua file.
if ( current_dir == nil or string.len(current_dir) <= 0 ) then
    current_dir = './'
end

config_loc = current_dir
deployment_instance = string.gsub(string.sub(current_dir, 1, -2), '(.*/)(.*)', '%2')
if ( deployment_instance == nil or deployment_instance == '.' or deployment_instance == '') then
    -- A value of './' for current_dir will lead to a value of '.' for
    -- deployment_instance.  Deal with that case here.
    deployment_instance = 'default'
end

cas_vault_token_file_name = nil
consul_token_file_name = nil
cas_tls_lock_file_name = nil
-- Vault token file name location is indeed qualified by tenant and instance.
cas_vault_token_file_name = config_loc .. '../../SASSecurityCertificateFramework/tokens/cas/' .. tenant_name .. '/' .. deployment_instance .. '/vault.token'
-- Consul token file name location is NOT qualified by tenant and instance.
consul_token_file_name = config_loc .. '../../SASSecurityCertificateFramework/tokens/consul/' .. deployment_instance .. '/client.token'
-- CAS TLS lock file name location is indeed qualified by tenant and instance.
cas_tls_lock_file_name = config_loc .. '../../../etc/SASSecurityCertificateFramework/tls/certs/cas/' .. tenant_name .. '/' .. deployment_instance .. '/cas-tls.lock'

--
-- Establish global variables related to directory locations of executables.
-- Example env.CAS_HOME: '/opt/sas/viya/home/SASFoundation'
--
viya_home_bin_dir = env.CAS_HOME .. '/../bin'

--
-- Functions
--

function abort_lua(message)
    log.trace( 'Lua: function abort_lua' )
    if ( message == nil or string.len(message) <= 0 ) then
        message = 'No abort_lua message supplied'
    end
    log.error( string.format('Lua: Error: abort_lua called, intentionally aborting Lua, message %s', message) )
    -- Intentionally abort this Lua code with a call to function error.
    -- Function error never returns, per the Lua specification.
    -- This call causes CAS to intentionally fail its startup sequence.
    -- Reference Lua 5.2 Reference Manual
    -- http://www.lua.org/manual/5.2/manual.html#pdf-error
    error(message)
    -- Through testing we have found that the above call to error will
    -- indeed abort CAS.  We call os.exit() here as an extra precaution.
    os.exit()
end

--
-- Returns a string which contains the file name of the Lua module in which
-- this get_lua_module_file_name function itself lives.  The return value
-- contains relative path information.  Returns nil if an error occurs.
--
function get_lua_module_file_name()
    -- Reference Lua Introspective Facilities
    -- https://www.lua.org/pil/23.1.html
    local stack_level = 1  -- This function itself.
    local debug_info = debug.getinfo(stack_level)
    if ( debug_info ~= nil and type(debug_info) == 'table' ) then
        if ( debug_info.source ~= nil and type(debug_info.source) == 'string' ) then
            if ( string.len(debug_info.source) > 1 and string.sub(debug_info.source, 1, 1) == '@' ) then
                local module_file_name = string.sub(debug_info.source, 2)
                return module_file_name
            end
        end
    end
    return nil
end

function file_exists(filename)
    log.trace( 'Lua: function file_exists' )
    --
    -- A previous implementation of this function attempted to open filename
    -- for reading.  If that file open attempt succeeded, this function
    -- returned true.  That's a bug.  If you do not have read permission
    -- on filename, then obviously you cannot open it for reading.  The
    -- implementation below does not suffer from that bug, but does rely
    -- on executing an external command.
    --
    if ( filename == nil or string.len(filename) <= 0 ) then
        return false
    end
    local result, stdout, stderr = os_execute_safe( string.format('stat %s', filename) )
    return result
end

function read_file(filename)
    log.trace( 'Lua: function read_file' )
    local f = io.open(filename, 'r')
    if (f ~= nil) then
        local s = f:read('*all')
        f:close()
        return s
    end
    return nil
end

function trim(s)
    log.trace( 'Lua: function trim' )
    -- Reference How to remove spaces from a string in Lua
    -- https://stackoverflow.com/questions/10460126/how-to-remove-spaces-from-a-string-in-lua
    if (s == nil) then
        return nil
    end
    return s:match( '^%s*(.-)%s*$' )
end

function trim_right(s)
    log.trace( 'Lua: function trim_right' )
    if (s == nil) then
        return nil
    end
    -- Reference Whitespace in C
    -- https://stackoverflow.com/questions/30033582/what-is-the-symbol-for-whitespace-in-c
    whitespace_table = { ' ', '\t', '\n', '\v', '\f', '\r' }
    -- for k, v in pairs(whitespace_table) do print(k, string.byte(v)) end  -- Testing and debugging.
    repeat
        local last_char = string.sub(s, string.len(s), string.len(s))
        local found_whitespace = false
        for k, v in pairs(whitespace_table) do
            if (last_char == v) then
                found_whitespace = true
                s = string.sub(s, 1, string.len(s) - 1)
                break
            end
        end
    until (not found_whitespace)
    return s
end

function os_capture(cmd)
    log.trace( 'Lua: function os_capture' )
    local result, stdout, stderr = os_execute_safe(cmd)
    if ( not result ) then
        return nil
    end
    -- Use Lua pattern matching (different from RegEx) to call upon Lua string.gsub.
    -- Replace \r occurrences with an empty string, and \n occurrences with an empty string.
    stdout = string.gsub(stdout, '\r', '')
    stdout = string.gsub(stdout, '\n', '')
    return stdout
end

--
-- os_execute_safe
--
-- Function os_execute_safe executes an operating system command
-- and captures its stdout and stderr by way of concrete file
-- redirection, using temporary files on the file system.  The
-- function intentionally does NOT make use of Lua io.popen,
-- which in testing appeared to cause CAS to crash.
--
function os_execute_safe(cmd)
    log.trace( 'Lua: function os_execute_safe' )
    --
    -- Reference Getting return status and program output
    -- https://stackoverflow.com/questions/7607384/getting-return-status-and-program-output/7607478
    --
    if ( cmd == nil or string.len(cmd) <= 0 ) then
        return nil, nil, nil
    end

    local tmp_file_name = os.tmpname()
    if ( tmp_file_name == nil or string.len(tmp_file_name) <= 0 ) then
        return nil, nil, nil
    end
    -- In unit testing on Lua 5.1.4 on Windows 7, os.tmpname produced
    -- a file in the root directory.  Thus, we attempt to fix it here.
    if ( string.sub(tmp_file_name, 1, 1) == '\\' ) then
        local os_temp_directory = os.getenv('TEMP')
        tmp_file_name = os_temp_directory .. tmp_file_name
    end
    local tmp_stdout_file_name = tmp_file_name .. '.stdout'
    local tmp_stderr_file_name = tmp_file_name .. '.stderr'
    -- print( tmp_file_name )
    -- print( tmp_stdout_file_name )
    -- print( tmp_stderr_file_name )

    -- Depending on the version of Lua executing, the underlying
    -- operating system, and the actual result of the command
    -- being executed, the Lua type of os.execute could be nil,
    -- a boolean, or a number.
    -- On Lua 5.1.4 (_VERSION == 5.1) on Linux, os.execute returns a Lua number type.
    -- On Lua 5.1.4 (_VERSION == 5.1) on Windows, os.execute returns a Lua number type.
    -- On tkLua (_VERSION == tkLua 5.2) on Linux, os.execute returns a Lua boolean type.
    -- Side note:  print( _VERSION )  -- Prints 'tkLua 5.2' as of 2017-07-15.
    local result = os.execute(cmd .. ' > ' .. tmp_stdout_file_name .. ' 2> ' .. tmp_stderr_file_name)

    -- Coerce result to a boolean.  Unfortunately, doing this causes us
    -- to lose the actual numerical result from os.execute, if it happens
    -- to be available on the underlying platform.  But the benefit of
    -- doing this is that we exhibit consistent behavior to our callers,
    -- regardless of the underlying platform.
    if ( result == true or result == 0 ) then
        result = true
    else
        -- result is nil
        -- result is false
        -- result is not 0
        result = false
    end
    if ( type(result) ~= 'boolean' ) then
        log.error('Lua: Error: Unknown Lua type returned from os.execute')
    end

    -- The os.tmpname function not only returns a string to a temporary
    -- file name, it also creates the temporary file.  Thus we remove it
    -- here, even though we never directly used it above.
    os.remove(tmp_file_name)

    local stdout_file = io.open(tmp_stdout_file_name)
    local stdout = stdout_file:read('*all')
    stdout_file:close()
    os.remove(tmp_stdout_file_name)

    local stderr_file = io.open(tmp_stderr_file_name)
    local stderr = stderr_file:read('*all')
    stderr_file:close()
    os.remove(tmp_stderr_file_name)

    return result, stdout, stderr
end

function os_execute(cmd)
    log.trace( 'Lua: function os_execute' )

    -- In testing, this function appears to cause CAS to crash.
    -- I suspect it is related to io.popen.  Thus, we are intentionally
    -- short-circuiting this function for now.  Use os_execute_safe
    -- instead.
    if (true) then
        return nil, nil
    end

    --
    -- Reference Lua Getting return status AND program output
    -- http://stackoverflow.com/questions/7607384/getting-return-status-and-program-output
    --
    if (cmd == nil) then
        return nil, nil
    end
    local file = io.popen(cmd)
    if (file == nil) then
        return nil, nil
    end
    local output = file:read('*all')
    -- ----------------------------------------------------------------------
    -- Values of rc table observed during testing with Lua 5.1.4 on CentOS
    -- release 6.7 (Final):
    -- ----------------------------------------------------------------------
    -- External    External    rc Index 0  rc Index 1  rc Index 2  rc Index 3
    -- command     command's   rc[0]       rc[1]       rc[2]       rc[3]
    -- present     exit code
    -- ----------------------------------------------------------------------
    -- yes         0           N/A         true        'exit'      0
    -- yes         none        N/A         true        'exit'      0
    -- yes         1           N/A         nil         'exit'      1
    -- yes         -1          N/A         nil         'exit'      255
    -- yes         7           N/A         nil         'exit'      7
    -- no          N/A         N/A         nil         'exit'      127
    local rc = { file:close() }
    -- Return the stdout output and the rc result table.
    return output, rc
end

function lua_whoami()
    log.trace( 'Lua: function lua_whoami' )
    local username = os.getenv('USER')
    if (username == nil) then
        username = os_capture('whoami')
    end
    return username
end

function lua_hostname()
    log.trace( 'Lua: function lua_hostname' )
    local hostname = os.getenv('HOSTNAME')
    if (hostname == nil) then
        hostname = os_capture('hostname')
    end
    return hostname
end

function write_string_to_file(text, output_file_name)
    log.trace( 'Lua: function write_string_to_file' )
    if ( text == nil ) then
        return
    end
    if ( output_file_name == nil or string.len(output_file_name) <= 0 ) then
        return
    end
    local f = io.open( output_file_name, 'w' )
    if ( f ~= nil ) then
        f:write( text )
        f:close()
        f = nil
    end
end

function read_file_as_table(filename)
    log.trace( 'Lua: function read_file_as_table' )
    if ( filename == nil or string.len(filename) <= 0 ) then
        return nil
    end
    local f = io.open( filename, 'r' )
    if ( f == nil ) then
        return nil
    end
    local text = f:read('*all')
    f:close()
    f = nil
    if ( text ~= nil and string.len(text) > 0 ) then
        local result_table = { }
        local index = 1
        for value in string.gmatch(text, '%w+') do
            result_table[index] = value
            index = index + 1
        end
        return result_table
    end
    return nil
end

function cas_print_var(name, value)
    -- log.trace( 'Lua: function cas_print_var' )  -- Too chatty.
    if (value == nil) then
        value = 'undefined/nil'
    end
    -- Note: type(nil) is indeed copacetic.
    log.debug( string.format('Lua: %s %s %s', name, type(value), value) )
end

function cas_print_vars()
    log.trace( 'Lua: function cas_print_vars' )
    --
    -- Lua fragment to run cas-print-vars.lua.
    --
    -- Place this fragment in casconfig_deployment.lua, then watch
    -- the CAS log files, as that is where print statements will
    -- show up.
    --
    log.debug( 'Running cas-print-vars.lua from casconfig_deployment.lua' )
    log.debug( '--------------------------------------------------------' )
    -- printvar_tag = 'cas-print-vars.lua-casconfig_deployment.lua:'
    printvar_tag = nil  -- Intentionally NOT local
    local result, message = pcall(dofile, config_loc .. '/cas-print-vars.lua')
    if (not result) then
        log.error( string.format('Lua: Error: dofile failed, message: %s', message) )
    end
end

function cas_tls_renew_certs()
    log.trace( 'Lua: function cas_tls_renew_certs' )

    if ( tenant_name == nil or string.len(tenant_name) <= 0 ) then
        log.error( string.format('Lua: Error: tenant_name is nil or empty') )
        return false
    end
    if ( deployment_instance == nil or string.len(deployment_instance) <= 0 ) then
        log.error( string.format('Lua: Error: deployment_instance is nil or empty') )
        return false
    end

    --
    -- Use the cas.lock function to attempt to acquire an advisory lock on the file
    -- specified in global variable cas_tls_lock_file_name.  Note that we intentionally
    -- never explicitly release this lock, because we want the lock to remain alive as
    -- long as the CAS process (in which this Lua code runs) remains alive.
    --
    if ( false ) then
        -- The cas.lock function exists.
        local lock_file_name = cas_tls_lock_file_name
        log.info( string.format('Lua: Attempting to acquire advisory lock on machine %s for file %s', lua_hostname(), lock_file_name) )
        local advisory_lock_result = cas.lock( lock_file_name )
        log.info( string.format('Lua: advisory_lock_result %s %s', type(advisory_lock_result), tostring(advisory_lock_result)) )  -- Lua nil is safe for type and tostring.
        if ( advisory_lock_result == nil ) then
            -- Failed to acquire lock.
            log.error( string.format('Lua: Error: Failed to acquire advisory lock, CAS TLS certificate renewal will NOT commence') )
            return false
        else
            -- Successfully acquired lock.
            log.info( string.format('Lua: Successfully acquired advisory lock, CAS TLS certificate renewal will commence') )
        end
    else
        -- The cas.lock function does NOT exist.
        log.warn( string.format('Lua: Warning: The cas.lock function does NOT exist, will proceed without acquiring an advisory lock') )
    end

    --
    -- Run accompanying bash script to renew CAS TLS certificates.
    --
    local cas_tls_sh_renew_cmd = string.format(viya_home_bin_dir .. '/cas-tls.sh renew --tenant %s --instance %s --headless', tenant_name, deployment_instance)
    log.debug( string.format('Lua: Running cas_tls_sh_renew_cmd %s', cas_tls_sh_renew_cmd) )
    local result, stdout, stderr = os_execute_safe(cas_tls_sh_renew_cmd)

    stdout = trim(stdout)
    stderr = trim(stderr)

    log.trace( string.format('Lua: Printing stdout from cas_tls_sh_renew_cmd %s', cas_tls_sh_renew_cmd) )
    log.trace( string.format('%s', stdout) )
    log.trace( string.format('Lua: Printing stderr from cas_tls_sh_renew_cmd %s', cas_tls_sh_renew_cmd) )
    log.trace( string.format('%s', stderr) )

    if ( not result ) then
        log.error( string.format('Lua: Error: Failed to execute cas_tls_sh_renew_cmd %s', cas_tls_sh_renew_cmd) )
        log.error( string.format('Lua: Printing stdout from cas_tls_sh_renew_cmd %s', cas_tls_sh_renew_cmd) )
        log.error( string.format('%s', stdout) )
        log.error( string.format('Lua: Printing stderr from cas_tls_sh_renew_cmd %s', cas_tls_sh_renew_cmd) )
        log.error( string.format('%s', stderr) )
    end

    return result
end

function is_vault_present()
    log.trace( 'Lua: function is_vault_present' )
    --
    -- Vault is present in a deployment if the Vault token file for CAS
    -- is present on the file system.
    --
    if ( cas_vault_token_file_name == nil ) then
        log.error( string.format('Lua: Error: cas_vault_token_file_name is nil') )
        return false
    end
    local vault_present = file_exists(cas_vault_token_file_name)
    return vault_present
end

function print_cas_tls_env_vars()
    log.trace( 'Lua: function print_cas_tls_env_vars' )
    --
    -- Print CAS TLS environment variables.
    --
    log.debug( 'Lua: Printing CAS TLS environment variables.' )
    log.debug( '-------------------------------- ')
    cas_print_var('env.CAS_CLIENT_SSL_REQUIRED', env.CAS_CLIENT_SSL_REQUIRED)
    cas_print_var('env.CAS_CLIENT_SSL_CA_LIST', env.CAS_CLIENT_SSL_CA_LIST)
    cas_print_var('env.CAS_CLIENT_SSL_CERT', env.CAS_CLIENT_SSL_CERT)
    cas_print_var('env.CAS_CLIENT_SSL_KEY', env.CAS_CLIENT_SSL_KEY)
    cas_print_var('env.CAS_CLIENT_SSL_KEYPW', env.CAS_CLIENT_SSL_KEYPW)
    cas_print_var('env.CAS_CLIENT_SSL_KEYPWLOC', env.CAS_CLIENT_SSL_KEYPWLOC)
    log.debug( '-------------------------------- ')
    cas_print_var('env.CAS_USE_HTTPS_ALL', env.CAS_USE_HTTPS_ALL)
    cas_print_var('env.CAS_CERTLOC', env.CAS_CERTLOC)
    cas_print_var('env.CAS_SSLREQCERT', env.CAS_SSLREQCERT)
    cas_print_var('env.CAS_PVTKEYLOC', env.CAS_PVTKEYLOC)
    cas_print_var('env.CAS_PVTKEYPASS', env.CAS_PVTKEYPASS)
    cas_print_var('env.CAS_PVTKEYPASSLOC', env.CAS_PVTKEYPASSLOC)
    log.debug( '-------------------------------- ')
    cas_print_var('env.CAS_INTERNODE_DATA_SSL', env.CAS_INTERNODE_DATA_SSL)
    cas_print_var('env.CAS_INTERNODE_SSL_CA_LIST', env.CAS_INTERNODE_SSL_CA_LIST)
    cas_print_var('env.CAS_INTERNODE_SSL_CERT', env.CAS_INTERNODE_SSL_CERT)
    cas_print_var('env.CAS_INTERNODE_SSL_KEY', env.CAS_INTERNODE_SSL_KEY)
    cas_print_var('env.CAS_INTERNODE_SSL_KEYPW', env.CAS_INTERNODE_SSL_KEYPW)
    cas_print_var('env.CAS_INTERNODE_SSL_KEYPWLOC', env.CAS_INTERNODE_SSL_KEYPWLOC)
    log.debug( '-------------------------------- ')
    cas_print_var('cas.DCTCPMENCRYPT', cas.DCTCPMENCRYPT)  -- This value lives in the CAS configuration space, not the environment space.
    cas_print_var('env.DCSSLPVTKEYPASSLOC', env.DCSSLPVTKEYPASSLOC)
end

function cas_tls_print_cas_tls_variables(message)
    log.trace( 'Lua: function cas_tls_print_cas_tls_variables' )
    if ( message == nil or string.len(message) <= 0 ) then
        -- message = 'Lua: Printing CAS TLS variables.'
        message = nil
    end
    if ( message ~= nil and string.len(message) > 0 ) then
        log.debug( message )
    end
    log.debug( string.format('Lua: CAS_TLS_CAL_ON=      %s', CAS_TLS_CAL_ON) )
    log.debug( string.format('Lua: CAS_TLS_REST_ON=     %s', CAS_TLS_REST_ON) )
    log.debug( string.format('Lua: CAS_TLS_INTERNODE_ON=%s', CAS_TLS_INTERNODE_ON) )
    log.debug( string.format('Lua: DC_TLS_VALUE=        %s', DC_TLS_VALUE) )
end

function cas_tls_establish_cas_tls_defaults()
    log.trace( 'Lua: function cas_tls_establish_cas_tls_defaults' )
    --
    -- The primary purpose of this function is to establish variables
    -- CAS_TLS_CAL_ON, CAS_TLS_REST_ON, CAS_TLS_INTERNODE_ON, and
    -- DC_TLS_VALUE at file scope.
    --
    -- Establish CAS TLS variables and their default values.
    --
    log.debug( 'Lua: Establishing CAS TLS variables and their default values.' )
    CAS_TLS_CAL_ON='false'
    CAS_TLS_REST_ON='false'
    CAS_TLS_INTERNODE_ON='false'
    --
    -- Establish Data Connector (DC) TLS variables and their default values.
    -- Possible values are 'YES', 'NO', 'OPTIONAL'.  'YES' implies DC will
    -- use TLS, 'OPTIONAL' implies DC might use TLS, depending on its
    -- client configuration.
    --
    log.debug( 'Lua: Establishing DC TLS variables and their default values.' )
    DC_TLS_VALUE='NO'
end

function cas_tls_get_tls_values_from_environment()
    log.trace( 'Lua: function cas_tls_get_tls_values_from_environment' )
    CAS_TLS_CAL_ON = env.CAS_CLIENT_SSL_REQUIRED
    CAS_TLS_REST_ON = env.CAS_USE_HTTPS_ALL
    CAS_TLS_INTERNODE_ON = env.CAS_INTERNODE_DATA_SSL
    DC_TLS_VALUE = cas.DCTCPMENCRYPT  -- This value lives in the CAS configuration space, not the environment space.
end

function cas_tls_print_consul_variables()
    log.trace( 'Lua: function cas_tls_print_consul_variables' )
    -- log.debug( 'Lua: Printing Consul variables.' )
    log.debug( string.format('Lua: CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED=  %s', CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED) )
    log.debug( string.format('Lua: CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED=      %s', CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED) )
    log.debug( string.format('Lua: CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED=     %s', CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED) )
    log.debug( string.format('Lua: CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED=         %s', CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED) )
    log.debug( string.format('Lua: CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_CASINTERNODE_ENABLED=%s', CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_CASINTERNODE_ENABLED) )
end

function cas_tls_get_tls_values_from_consul()
    log.trace( 'Lua: function cas_tls_get_tls_values_from_consul' )
    if ( tenant_name == nil or string.len(tenant_name) <= 0 ) then
        log.error( string.format('Lua: Error: tenant_name is nil or empty') )
        return
    end
    if ( deployment_instance == nil or string.len(deployment_instance) <= 0 ) then
        log.error( string.format('Lua: Error: deployment_instance is nil or empty') )
        return
    end
    if ( consul_token_file_name == nil ) then
        log.error( string.format('Lua: Error: consul_token_file_name is nil') )
        return
    end
    -- These variable are intentionally NOT local, because we want them
    -- to be available at file scope once this function is called.
    -- Read Consul global values.
    log.debug( 'Lua: Querying Consul for Global TLS KV pairs.' )
    CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED=os_capture(viya_home_bin_dir .. '/sas-bootstrap-config --token-file ' .. consul_token_file_name .. ' kv read config/application/sas.security/network.sasData.enabled')
    CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED=os_capture(viya_home_bin_dir .. '/sas-bootstrap-config --token-file ' .. consul_token_file_name .. ' kv read config/application/sas.security/network.web.enabled')
    -- Read Consul CAS-specific values.
    log.debug( 'Lua: Querying Consul for CAS-specific TLS KV pairs.' )
    -- TXDX: Consul keys below should be parameterized, instead of using cas-shared-default.
    CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED=os_capture(viya_home_bin_dir .. '/sas-bootstrap-config --token-file ' .. consul_token_file_name .. ' kv read config/cas-' .. tenant_name .. '-' .. deployment_instance .. '/sas.security/network.sasData.enabled')
    CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED=os_capture(viya_home_bin_dir .. '/sas-bootstrap-config --token-file ' .. consul_token_file_name .. ' kv read config/cas-' .. tenant_name .. '-' .. deployment_instance .. '-http' .. '/sas.security/network.web.enabled')
    CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_CASINTERNODE_ENABLED=os_capture(viya_home_bin_dir .. '/sas-bootstrap-config --token-file ' .. consul_token_file_name .. ' kv read config/cas-' .. tenant_name .. '-' .. deployment_instance .. '/sas.security/network.casInternode.enabled')
end

function cas_tls_inspect_consul_values()
    log.trace( 'Lua: function cas_tls_inspect_consul_values' )
    if (
        CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED == nil or
        CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED == nil or
        CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED == nil or
        CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED == nil or
        CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_CASINTERNODE_ENABLED == nil
        ) then
        log.error( string.format(
            'Lua: Error: One or more CAS TLS Consul variables are nil, ' ..
            'please confirm that the CAS process OS user has READ permission on the Consul client token file')
            )
        abort_lua( 'Failed to read CAS TLS values from Consul' )
    end
end

function cas_tls_munge_cas_tls_variables()
    log.trace( 'Lua: function cas_tls_munge_cas_tls_variables' )
    --
    -- Override default CAS TLS values with values from Consul,
    -- if those values are indeed present in Consul.
    --
    log.debug( string.format('Lua: Munging and overriding CAS TLS default values with values from Consul.') )
    -- Munge Consul global values.
    if ( CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED ~= nil and string.len(CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED) > 0 ) then
        CAS_TLS_CAL_ON = CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED
    end
    if ( CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED ~= nil and string.len(CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED) > 0 ) then
        CAS_TLS_REST_ON = CONSUL_GLOBAL_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED
    end
    -- Munge Consul CAS-specific values.
    if ( CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED ~= nil and string.len(CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED) > 0 ) then
        CAS_TLS_CAL_ON = CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_SASDATA_ENABLED
    end
    if ( CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED ~= nil and string.len(CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED) > 0 ) then
        CAS_TLS_REST_ON = CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_WEB_ENABLED
    end
    if ( CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_CASINTERNODE_ENABLED ~= nil and string.len(CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_CASINTERNODE_ENABLED) > 0 ) then
        CAS_TLS_INTERNODE_ON = CONSUL_CAS_VALUE_SAS_SECURITY_NETWORK_CASINTERNODE_ENABLED
    end
end

--
-- Main
--

log.debug( '---------------------------------------------------' )
log.debug( 'Lua: Begin Main cas-tls.lua' )
log.debug( '---------------------------------------------------' )
log.debug( string.format('Lua: log.file %s', tostring(log.file)) )

datetime_now = os.time()
timestamp_now = os.date('%Y%m%d%H%M%S', datetime_now)
human_datetime_now = os.date('%A %B %d %Y %H:%M:%S%p', datetime_now)

log.debug( string.format('Lua: Lua _VERSION %s', _VERSION) )
log.debug( string.format('Lua: Lua code running at timestamp_now %s human_datetime_now %s', timestamp_now, human_datetime_now) )
log.debug( string.format('Lua: Lua code running as user %s', lua_whoami()) )
log.debug( string.format('Lua: Lua code running on machine %s', lua_hostname()) )
log.debug( string.format('Lua: env.CAS_VIRTUAL_HOST %s', env.CAS_VIRTUAL_HOST) )            -- Example: 'myhost.example.com'
log.debug( string.format('Lua: cas.role %s', cas.role) )                                    -- Example: 'CONTROLLER'
log.debug( string.format('Lua: cas.command %s', cas.command) )                              -- Example: 'START'
log.debug( string.format('Lua: cas.tenantid %s', cas.tenantid) )                            -- Example: nil
log.debug( string.format('Lua: tenant_name %s', tenant_name) )                              -- Example: 'shared'
log.debug( string.format('Lua: current_dir %s', current_dir) )                              -- Example: '/opt/sas/viya/home/SASFoundation/../../config/etc/cas/default/'
log.debug( string.format('Lua: config_loc %s', config_loc) )                                -- Example: '/opt/sas/viya/home/SASFoundation/../../config/etc/cas/default/'
log.debug( string.format('Lua: deployment_instance %s', deployment_instance) )              -- Example: 'default'
log.debug( string.format('Lua: cas_tls_lock_file_name %s', cas_tls_lock_file_name) )        -- Example: '/opt/sas/viya/home/SASFoundation/../../config/etc/cas/default/../../../etc/SASSecurityCertificateFramework/tls/certs/cas/shared/default/cas-tls.lock'
log.debug( string.format('Lua: cas_vault_token_file_name %s', cas_vault_token_file_name) )  -- Example: '/opt/sas/viya/home/SASFoundation/../../config/etc/cas/default/../../SASSecurityCertificateFramework/tokens/cas/shared/default/vault.token'
log.debug( string.format('Lua: consul_token_file_name %s', consul_token_file_name) )        -- Example: '/opt/sas/viya/home/SASFoundation/../../config/etc/cas/default/../../SASSecurityCertificateFramework/tokens/consul/default/client.token'
log.debug( string.format('Lua: env.CAS_HOME %s', env.CAS_HOME) )                            -- Example: '/opt/sas/viya/home/SASFoundation'
log.debug( string.format('Lua: viya_home_bin_dir %s', viya_home_bin_dir) )                  -- Example: '/opt/sas/viya/home/SASFoundation/../bin'

--
-- Detect whether Vault is present in this deployment.
--

--
-- Algorithm for detecting whether Consul/Vault are present and/or
-- whether we have a Programming Only deployment:
--
--      If we have a Vault token file on the file system,
--          then Vault is present within the deployment.
--      If Vault is present within the deployment,
--          then Consul is also present in the deployment.
--      If we do not have a Vault token file on the file system,
--          then Vault/Consul are not present within the deployment,
--          and we can assume a Programming Only deployment.
--      If we have a Programming Only deployment,
--          then we do NOT renew CAS TLS certificates.
--
vault_present = is_vault_present()
log.debug( string.format('Lua: vault_present %s %s', type(vault_present), vault_present) )

--
-- CAS Process Types
--
-- Main controller: role=controller, command=start -- A controller process in server space (upstairs)
-- Backup controller: role=controller, command=join -- A backup controller process in server space (upstairs)
-- Main worker: role=worker, command=join -- A worker process in server space (upstairs)
-- Worker: role=worker, command=session -- A worker process in session space  (downstairs)
-- Session controller: role=controller, command=session -- A controller process in session space (downstairs)
-- Backup session controller: role=backup, command=session -- A backup controller process in session space (downstairs)
--

--
-- Detect CAS process startup type.
--

log.debug( string.format('Lua: cas.command %s cas.role %s user %s', cas.command, cas.role, lua_whoami()) )

is_cas_main_controller_starting = (cas.command:upper() == 'START')
is_cas_backup_controller_starting = ((cas.role:upper() == 'CONTROLLER') and (cas.command:upper() == 'JOIN'))
is_cas_main_worker_starting = ((cas.role:upper() == 'WORKER') and (cas.command:upper() == 'JOIN'))
is_cas_session_starting = (cas.command:upper() == 'SESSION')

log.debug( string.format('Lua: is_cas_main_controller_starting %s %s', type(is_cas_main_controller_starting), is_cas_main_controller_starting) )
log.debug( string.format('Lua: is_cas_backup_controller_starting %s %s', type(is_cas_backup_controller_starting), is_cas_backup_controller_starting) )
log.debug( string.format('Lua: is_cas_main_worker_starting %s %s', type(is_cas_main_worker_starting), is_cas_main_worker_starting) )
log.debug( string.format('Lua: is_cas_session_starting %s %s', type(is_cas_session_starting), is_cas_session_starting) )

--
-- Perform CAS TLS certificate management activities.
--

if ( vault_present ) then
    --
    -- Vault is present in this deployment.
    --
    if ( is_cas_main_controller_starting or is_cas_backup_controller_starting ) then
        --
        -- A CAS controller is starting in a Vault enabled deployment.
        --
        cas_tls_establish_cas_tls_defaults()
        cas_tls_print_cas_tls_variables()
        -- cas_tls_get_tls_values_from_consul()
        cas_tls_get_tls_values_from_environment()
        -- cas_tls_print_consul_variables()
        -- cas_tls_inspect_consul_values()
        -- cas_tls_munge_cas_tls_variables()
        cas_tls_print_cas_tls_variables()

        --
        -- For a CAS controller, as a simplification technique, we always commence CAS
        -- TLS certificate renewal.  We do this because it simplifies both the CAS
        -- case and the Data Connector (DC) case, and because the performance impact
        -- of TLS certificate renewal, although generally small to begin with, is less
        -- of a concern when a CAS controller is starting.
        --

        log.debug( 'Lua: A CAS CONTROLLER is starting in a Vault enabled deployment, YES always renew CAS TLS certificates.' )
        log.debug( 'Lua: Renewing CAS TLS certs.' )
        cas_tls_cert_renewal_result = cas_tls_renew_certs()
        log.debug( string.format('Lua: cas_tls_cert_renewal_result %s %s', type(cas_tls_cert_renewal_result), cas_tls_cert_renewal_result) )
        if ( not cas_tls_cert_renewal_result ) then
            log.error( string.format('Lua: Error: CAS TLS certificate renewal failed, cas_tls_cert_renewal_result %s %s', type(cas_tls_cert_renewal_result), cas_tls_cert_renewal_result) )
            abort_lua( string.format('CAS TLS certificate renewal failed on machine %s', lua_hostname()) )
        end
    elseif ( is_cas_main_worker_starting ) then
        --
        -- A CAS main worker is starting in a Vault enabled deployment.
        --
        cas_tls_establish_cas_tls_defaults()
        cas_tls_print_cas_tls_variables()
        -- cas_tls_get_tls_values_from_consul()
        cas_tls_get_tls_values_from_environment()
        -- cas_tls_print_consul_variables()
        -- cas_tls_inspect_consul_values()
        -- cas_tls_munge_cas_tls_variables()
        cas_tls_print_cas_tls_variables()

        log.debug( string.format('Lua: A CAS WORKER is starting in a Vault enabled deployment.') )

        --
        -- A technique is used here to maintain simplicity.  If a CAS worker is starting,
        -- and if ANY CAS TLS or Data Connector (DC) TLS related variable is engaged,
        -- then we renew TLS certificates.  Technically, since this is a worker node, we
        -- only need to renew TLS certificates if any of (a.) CAS Internode TLS is ON,
        -- (b.) CAS REST TLS is ON, or (c.) DC TLS is YES or OPTIONAL.  But to keep the
        -- logic below simple and to support future proofing, we perform a renewal if
        -- ANY of those variables are engaged.
        --

        if ( CAS_TLS_CAL_ON == 'true' or CAS_TLS_REST_ON == 'true' or CAS_TLS_INTERNODE_ON == 'true' or DC_TLS_VALUE == 'YES' or DC_TLS_VALUE == 'OPTIONAL' ) then
            log.debug( string.format('Lua: CAS TLS is enabled on a CAS or DC port on CAS WORKER node, YES renew CAS TLS certificates.') )
            log.debug( 'Lua: Renewing CAS TLS certs.' )
            cas_tls_cert_renewal_result = cas_tls_renew_certs()
            log.debug( string.format('Lua: cas_tls_cert_renewal_result %s %s', type(cas_tls_cert_renewal_result), cas_tls_cert_renewal_result) )
            if ( not cas_tls_cert_renewal_result ) then
                log.error( string.format('Lua: Error: CAS TLS certificate renewal failed, cas_tls_cert_renewal_result %s %s', type(cas_tls_cert_renewal_result), cas_tls_cert_renewal_result) )
                abort_lua( string.format('CAS TLS certificate renewal failed on machine %s', lua_hostname()) )
            end
            log.debug( string.format('Lua: cas.command %s cas.role %s user %s', cas.command, cas.role, lua_whoami()) )
        else
            log.debug( string.format('Lua: CAS TLS is NOT enabled on any CAS port on CAS WORKER node, thus we will NOT take action.') )
        end
    elseif ( is_cas_session_starting ) then
        --
        -- A CAS session is starting in a Vault enabled deployment.
        --
        log.debug( string.format('Lua: A CAS SESSION is starting in a Vault enabled deployment, thus we will NOT take action.') )
    else
        --
        -- Failed to detect CAS process startup type.
        --
        log.error( string.format('Lua: Error: Failed to detect CAS process startup type, unrecognized CAS command cas.command %s', cas.command) )
    end
else
    --
    -- Vault is not present in this deployment.
    --
    log.warn( string.format('Lua: Warning: Vault is not present within this deployment, thus we will NOT take action.') )
end

---
--- Print CAS TLS environment variables.
---

print_cas_tls_env_vars()

log.debug( '-------------------------------------------------' )
log.debug( 'Lua: End Main cas-tls.lua' )
log.debug( '-------------------------------------------------' )

log.info( 'Lua: cas-tls.lua ends' )
