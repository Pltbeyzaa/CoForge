import os
import json
import logging
import google.generativeai as genai
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

# 🔑 AŞKO BURAYA GOOGLE AI STUDIO'DAN ALDIĞIN ÜCRETSİZ ANAHTARI YAPIŞTIR
GEMINI_API_KEY = os.environ.get('GCP_API_KEY')

def chat_with_scrum_master(
    project_title: str, 
    project_description: str, 
    team_members: List[Dict[str, Any]], 
    user_message: str
) -> dict:
    """
    Otonom AI Scrum Master - GEMINI (ÜCRETSİZ) VERSİYON
    """
    if GEMINI_API_KEY == "BURAYA_YAPISTIR":
        return {"error": "Aşko, lütfen Google AI Studio'dan aldığın anahtarı koda ekle! 😎"}

    # Gemini'yi yapılandırıyoruz
    genai.configure(api_key=GEMINI_API_KEY)
    
    team_info_str = json.dumps(team_members, ensure_ascii=False, indent=2)

    # Gemini'ye nasıl davranması gerektiğini söylüyoruz
    system_instruction = f"""
    Sen CoForge platformunda son derece zeki, esprili ve profesyonel bir AI Scrum Master'sın.
    Yönettiğin Proje: {project_title}
    Mevcut Takım Üyeleri: {team_info_str}
    
    KURALLAR:
    1. Kullanıcı seninle sohbet ediyorsa ona doğal, samimi ve akıllıca cevap ver.
    2. Eğer görev dağıtman isteniyorsa takımın yetkinliklerine göre mantıklı görevler uydur.
    3. YANIT FORMATI: Arayüzün çökmemesi için KESİNLİKLE aşağıdaki JSON formatında dönmelisin. Başka hiçbir metin ekleme.
    
    JSON FORMATI:
    {{
        "ai_message": "Kullanıcıya verdiğin akıcı sohbet cevabı.",
        "assigned_tasks": [
            {{"task_name": "Görev adı", "assignee": "Kişi Adı"}}
        ]
    }}
    Görev istenmiyorsa assigned_tasks listesini boş [] bırak.
    """

    try:
        # JSON formatında cevap vermesi için modeli ayarlıyoruz
        # Eski 1.5 sürümü yerine güncel 2.5 sürümünü kullanıyoruz
        model = genai.GenerativeModel('gemini-2.5-flash', 
                                      generation_config={"response_mime_type": "application/json"})
        
        chat = model.start_chat()
        prompt = f"Sistem Talimatı: {system_instruction}\n\nKullanıcı Mesajı: {user_message}"
        response = chat.send_message(prompt)
        
        # Gelen JSON'u Python sözlüğüne çevirip arayüze yolluyoruz
        scrum_response = json.loads(response.text)
        
        # Eğer değerlendirme kısmı eksik dönerse hata almamak için ekliyoruz
        if "evaluations" not in scrum_response:
            scrum_response["evaluations"] = []
            
        return scrum_response

    except json.JSONDecodeError:
        logger.error("Gemini JSON dışı bir yanıt verdi.")
        return {"error": "Scrum Master şu an biraz meşgul, lütfen tekrar dene."}
    except Exception as e:
        logger.exception("Gemini servisi ile konuşurken hata oluştu.")
        return {"error": f"Bir hata oluştu: {str(e)}"}