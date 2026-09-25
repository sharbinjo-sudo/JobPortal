import os
import requests
import json

payload = {
    "service_id": "service_26wkk5m",
    "template_id": "template_xph8aod",
    "user_id": "hdx6Md_OsAKQ6a_KB",
    "accessToken": "uN1rOeub7tscyV58fVfw6",
    "template_params": {
        "app_name": "Job Portal",
        "user_name": "Sharbin",
        "user_email": "sharbinjo@gmail.com",
        "user_role": "Admin",
        "registration_date": "September 25, 2026",
        "role_message": "Welcome to the platform.",
        "login_url": "http://localhost:8080/login",
        "support_email": "support@example.com",
        "current_year": "2026"
    }
}

try:
    response = requests.post(
        "https://api.emailjs.com/api/v1.0/email/send", 
        json=payload,
        headers={"Content-Type": "application/json"}
    )
    print("Status code:", response.status_code)
    print("Response text:", response.text)
except Exception as e:
    print("Error:", e)
