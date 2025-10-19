import requests

class TeacherClient:
    BACKEND_BASE_URL = "http://127.0.0.1:8000"  # Change this to your server's base URL
    
    def __init__(self, email, password):
        self.authenticate(email, password)
        self.access_token = None

    def authenticate(self, email, password):
        """Authenticate the teacher and retrieve the access token."""
        url = f"{TeacherClient.BACKEND_BASE_URL}/api/auth/token/"
        data = {
            "email": email,
            "password": password
        }
        response = requests.post(url, data=data)
        if response.status_code == 200:
            self.access_token = response.json().get("access")
        else:
            print("Authentication failed:", response.json())
            quit()

    def get_dashboard_data(self, start_date="", end_date="", date_range=""):
        """Fetch the dashboard data for the teacher."""
        if not self.access_token:
            print("You must authenticate first.")
            return

        url = f"{TeacherClient.BACKEND_BASE_URL}/api/teacher/get_dashboard_data/"
        headers = {
            "Authorization": f"Bearer {self.access_token}"
        }
        params = {
            "start_date": start_date,
            "end_date": end_date,
            "date_range": date_range
        }
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            return response.json()
        else:
            print("Failed to fetch dashboard data:", response.json())
            return None


