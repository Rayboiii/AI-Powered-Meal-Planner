import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv

load_dotenv()

def get_db_connection():
    """Create and return a database connection"""
    try:
        connection = mysql.connector.connect(
            host=os.getenv('DATABASE_HOST', '127.0.0.1'),
            user=os.getenv('DATABASE_USER', 'root'),
            password=os.getenv('DATABASE_PASSWORD'),
            database=os.getenv('DATABASE_NAME'),
            port=int(os.getenv('DATABASE_PORT', 3307)),
            auth_plugin='mysql_native_password',  
            charset='utf8mb4',
            use_unicode=True
        )
        if connection.is_connected():
            # Remove or comment this line to reduce console spam
            # print(f"✅ Successfully connected to MySQL Server version {connection.get_server_info()}")
            return connection
    except Error as e:
        print(f"❌ Error connecting to MySQL: {e}")
        print(f"Host: {os.getenv('DATABASE_HOST')}")
        print(f"User: {os.getenv('DATABASE_USER')}")
        print(f"Database: {os.getenv('DATABASE_NAME')}")
        return None

def execute_query(query, params=None):
    """Execute a query and return results"""
    connection = get_db_connection()
    if connection:
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
            print(f"❌ Error executing query: {e}")
            print(f"Query: {query}")
            return None
        finally:
            if connection.is_connected():
                connection.close()
    return None