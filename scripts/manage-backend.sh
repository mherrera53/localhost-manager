#!/bin/bash

HOSTS_JSON="$HOME/localhost-manager/conf/hosts.json"
SERVICES_DIR="$HOME/localhost-manager/services"
LOGS_DIR="$HOME/localhost-manager/logs"

mkdir -p "$SERVICES_DIR"
mkdir -p "$LOGS_DIR"

case "$1" in
    start)
        DOMAIN="$2"
        if [ -z "$DOMAIN" ]; then
            echo "Usage: $0 start <domain>"
            exit 1
        fi
        
        if [ ! -f "$HOSTS_JSON" ]; then
            echo "Error: hosts.json not found"
            exit 1
        fi
        
        /opt/homebrew/opt/php@8.4/bin/php -r "
            \$hosts = json_decode(file_get_contents('$HOSTS_JSON'), true);
            if (!isset(\$hosts['$DOMAIN'])) {
                echo 'Error: Domain not found\n';
                exit(1);
            }
            
            \$config = \$hosts['$DOMAIN'];
            \$stack = isset(\$config['stack']) ? \$config['stack'] : 'frontend';
            
            if (\$stack !== 'backend') {
                echo 'Error: Not a backend project\n';
                exit(1);
            }
            
            \$docroot = \$config['docroot'];
            \$port = isset(\$config['port']) ? \$config['port'] : 3000;
            \$framework = '';
            
            if (file_exists(\$docroot . '/artisan')) {
                \$framework = 'laravel';
            } elseif (file_exists(\$docroot . '/manage.py')) {
                \$framework = 'django';
            } elseif (file_exists(\$docroot . '/package.json')) {
                \$content = file_get_contents(\$docroot . '/package.json');
                if (strpos(\$content, '\"next\"') !== false) {
                    \$framework = 'nextjs';
                } elseif (strpos(\$content, '\"nuxt\"') !== false) {
                    \$framework = 'nuxt';
                } else {
                    \$framework = 'node';
                }
            }
            
            echo json_encode([
                'docroot' => \$docroot,
                'port' => \$port,
                'framework' => \$framework
            ]);
        "
        
        PROJECT_INFO=$(/opt/homebrew/opt/php@8.4/bin/php -r "
            \$hosts = json_decode(file_get_contents('$HOSTS_JSON'), true);
            if (isset(\$hosts['$DOMAIN'])) {
                \$config = \$hosts['$DOMAIN'];
                echo json_encode([
                    'docroot' => \$config['docroot'],
                    'port' => isset(\$config['port']) ? \$config['port'] : 3000
                ]);
            }
        ")
        
        DOCROOT=$(echo $PROJECT_INFO | jq -r '.docroot')
        PORT=$(echo $PROJECT_INFO | jq -r '.port')
        
        PID_FILE="$SERVICES_DIR/$DOMAIN.pid"
        LOG_FILE="$LOGS_DIR/$DOMAIN.log"
        
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 $PID 2>/dev/null; then
                echo "Service already running with PID $PID"
                exit 0
            fi
        fi
        
        cd "$DOCROOT" || exit 1
        
        # Auto-detect and run appropriate command
        if [ -f "artisan" ]; then
            # Laravel project
            nohup php artisan serve --host=0.0.0.0 --port=$PORT > "$LOG_FILE" 2>&1 &
            echo $! > "$PID_FILE"
            echo "Started Laravel service on port $PORT"
            
        elif [ -f "manage.py" ]; then
            # Django project
            nohup python manage.py runserver 0.0.0.0:$PORT > "$LOG_FILE" 2>&1 &
            echo $! > "$PID_FILE"
            echo "Started Django service on port $PORT"
            
        elif [ -f "package.json" ]; then
            # Node.js project - detect package manager and dev command
            PACKAGE_MANAGER="npm"
            DEV_COMMAND="dev"
            
            # Check for yarn.lock or pnpm-lock.yaml
            if [ -f "yarn.lock" ]; then
                PACKAGE_MANAGER="yarn"
            elif [ -f "pnpm-lock.yaml" ]; then
                PACKAGE_MANAGER="pnpm"
            fi
            
            # Detect dev command from package.json scripts
            if grep -q '"dev"' package.json; then
                DEV_COMMAND="dev"
            elif grep -q '"watch"' package.json; then
                DEV_COMMAND="watch"
            elif grep -q '"start:dev"' package.json; then
                DEV_COMMAND="start:dev"
            elif grep -q '"serve"' package.json; then
                DEV_COMMAND="serve"
            elif grep -q '"start"' package.json; then
                DEV_COMMAND="start"
            fi
            
            echo "Using: $PACKAGE_MANAGER run $DEV_COMMAND"
            
            if [ "$PACKAGE_MANAGER" = "yarn" ]; then
                nohup yarn $DEV_COMMAND > "$LOG_FILE" 2>&1 &
            elif [ "$PACKAGE_MANAGER" = "pnpm" ]; then
                nohup pnpm run $DEV_COMMAND > "$LOG_FILE" 2>&1 &
            else
                nohup npm run $DEV_COMMAND > "$LOG_FILE" 2>&1 &
            fi
            
            echo $! > "$PID_FILE"
            echo "Started Node.js service with $PACKAGE_MANAGER $DEV_COMMAND"
            
        else
            echo "Error: Unknown project type"
            exit 1
        fi
        ;;
        
    stop)
        DOMAIN="$2"
        if [ -z "$DOMAIN" ]; then
            echo "Usage: $0 stop <domain>"
            exit 1
        fi
        
        PID_FILE="$SERVICES_DIR/$DOMAIN.pid"
        
        if [ ! -f "$PID_FILE" ]; then
            echo "Service not running"
            exit 0
        fi
        
        PID=$(cat "$PID_FILE")
        
        if kill -0 $PID 2>/dev/null; then
            kill $PID
            rm "$PID_FILE"
            echo "Stopped service (PID $PID)"
        else
            echo "Service not running (stale PID file)"
            rm "$PID_FILE"
        fi
        ;;
        
    status)
        DOMAIN="$2"
        if [ -z "$DOMAIN" ]; then
            echo "All backend services:"
            for pid_file in "$SERVICES_DIR"/*.pid; do
                [ -f "$pid_file" ] || continue
                domain=$(basename "$pid_file" .pid)
                pid=$(cat "$pid_file")
                if kill -0 $pid 2>/dev/null; then
                    echo "  $domain: running (PID $pid)"
                else
                    echo "  $domain: stopped"
                fi
            done
        else
            PID_FILE="$SERVICES_DIR/$DOMAIN.pid"
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if kill -0 $PID 2>/dev/null; then
                    echo "Service running (PID $PID)"
                else
                    echo "Service stopped (stale PID file)"
                fi
            else
                echo "Service not running"
            fi
        fi
        ;;
        
    logs)
        DOMAIN="$2"
        if [ -z "$DOMAIN" ]; then
            echo "Usage: $0 logs <domain> [lines]"
            exit 1
        fi
        
        LINES="${3:-50}"
        LOG_FILE="$LOGS_DIR/$DOMAIN.log"
        
        if [ -f "$LOG_FILE" ]; then
            tail -n $LINES "$LOG_FILE"
        else
            echo "No logs found"
        fi
        ;;
        
    restart)
        DOMAIN="$2"
        if [ -z "$DOMAIN" ]; then
            echo "Usage: $0 restart <domain>"
            exit 1
        fi
        
        $0 stop "$DOMAIN"
        sleep 1
        $0 start "$DOMAIN"
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status|logs} <domain> [args]"
        echo ""
        echo "Commands:"
        echo "  start <domain>         - Start backend service"
        echo "  stop <domain>          - Stop backend service"
        echo "  restart <domain>       - Restart backend service"
        echo "  status [domain]        - Show service status"
        echo "  logs <domain> [lines]  - Show service logs"
        exit 1
        ;;
esac
