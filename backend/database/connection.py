import mysql.connector
from mysql.connector import Error, pooling
import os
import logging
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

_pool: pooling.MySQLConnectionPool | None = None


def _get_pool() -> pooling.MySQLConnectionPool:
    global _pool
    if _pool is None:
        _pool = pooling.MySQLConnectionPool(
            pool_name="meal_planner_pool",
            pool_size=5,
            host=os.getenv('DATABASE_HOST', '127.0.0.1'),
            user=os.getenv('DATABASE_USER', 'root'),
            password=os.getenv('DATABASE_PASSWORD'),
            database=os.getenv('DATABASE_NAME'),
            port=int(os.getenv('DATABASE_PORT', 3307)),
            auth_plugin='mysql_native_password',
            charset='utf8mb4',
            use_unicode=True,
        )
    return _pool


def execute_query(query, params=None):
    """Execute a query and return results. Uses a connection pool."""
    try:
        connection = _get_pool().get_connection()
    except Error as e:
        logger.error("Error getting connection from pool: %s", e)
        return None

    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, params or ())
        if query.strip().upper().startswith('SELECT'):
            result = cursor.fetchall()
        else:
            connection.commit()
            result = cursor.lastrowid
        cursor.close()
        return result
    except Error as e:
        logger.error("Error executing query: %s", e)
        return None
    finally:
        connection.close()  # Returns connection to the pool
