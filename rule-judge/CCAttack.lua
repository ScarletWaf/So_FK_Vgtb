--获取用户真实ip
function getIp()
    local client_IP = ngx.req.get_headers()["X-Real-IP"]
    if client_IP == nil then
        client_IP = ngx.req.get_headers()["x_forwarded_for"]
    end
    if client_IP == nil then
        client_IP = ngx.var.remote_addr
    end
    return client_IP
end

function exec_ban_ip()
    local redis_key = "ip_blacklist"
    --禁封ip时间
    local ip_block_time = 10
    --在 10 秒内监控访问
    local ip_time_out = 1
    --最大访问次数
    local ip_max_times = 15
    --读取nginx 变量 username
    --local USERNAME = ngx.var.username
    --连接redis
    local redis = require "resty.redis"
    local red = redis:new()
    red:set_timeouts(5000) -- 1 sec
    local ok, err = red:connect("127.0.0.1", 6379)

    if not ok then
        ngx.say("failed to connect: ", err)
        red:close()
    end
    --查询redis中是否已经存在该ip ,存在即证明被ban
    is_ban, err = red:get("BANNED-"..getIp())
    if is_ban ~= "1" then
        --查询数据库中是否已经有该ip访问
        ip_count, err = red:get("COUNT-"..getIp())
        --如果ip 不存在redis中
        if ip_count == ngx.null then
            res, err = red:set("COUNT-"..getIp(),1)
            res2, err2 = red:expire("COUNT-"..getIp(),ip_time_out) --单个ip检测时长
        else
            ip_count = ip_count + 1
            if ip_count >= ip_max_times then
                res, err = red:set("BANNED-"..getIp(),1)
                res2, err2 = red:expire("BANNED-"..getIp(),ip_block_time)

                --危险流量 ，日志记录开启，准备发送到日志服务器
            else
                res, err = red:set("COUNT-"..getIp(),ip_count)
                res2, err2 = red:expire("COUNT-"..getIp(),ip_time_out)
            end
        end
    else
        red:expire("BANNED-"..getIp(),ip_block_time)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    red:close()
end

function CCAttack()
    exec_ban_ip()
end
