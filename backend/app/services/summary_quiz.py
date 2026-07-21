"""
Summary and Quiz generation service for Sourcely.
Uses LangChain structured output to generate a summary and quiz
from ingested document text.
"""

import json
import os
from typing import Optional

from pydantic import BaseModel, Field
from app.config import get_settings


class QuizQuestion(BaseModel):
    """A single quiz question with its answer."""
    question: str = Field(description="A question about the content")
    answer: str = Field(description="The correct answer to the question")


class SummaryQuizOutput(BaseModel):
    """Structured output for summary and quiz generation."""
    summary: str = Field(description="A comprehensive summary of the content in 3-5 paragraphs")
    quiz: list[QuizQuestion] = Field(
        description="3 to 5 quiz questions with answers based on the content"
    )


def generate_summary_and_quiz(full_text: str) -> dict:
    """
    Generate a summary and quiz questions from the full extracted text.
    Uses HuggingFace Inference API via LangChain.

    Args:
        full_text: The complete text content from the ingested source.

    Returns:
        Dict with 'summary' (str) and 'quiz' (list of {question, answer}).
    """
    settings = get_settings()

    # Truncate text if too long (to fit within model context limits)
    max_chars = 12000
    truncated_text = full_text[:max_chars] if len(full_text) > max_chars else full_text

    try:
        from app.services.agent import _get_llm

        llm = _get_llm()

        prompt = f"""You are an expert content analyst. Analyze the following text and provide:

1. A comprehensive summary (3-5 paragraphs covering the main ideas)
2. 3 to 5 quiz questions with answers based on the content

TEXT TO ANALYZE:
---
{truncated_text}
---

Respond in the following JSON format ONLY (no other text):
{{
  "summary": "Your comprehensive summary here...",
  "quiz": [
    {{"question": "Question 1?", "answer": "Answer 1"}},
    {{"question": "Question 2?", "answer": "Answer 2"}},
    {{"question": "Question 3?", "answer": "Answer 3"}}
  ]
}}

JSON Response:"""

        response = llm.invoke(prompt)

        # Parse the JSON response
        # Try to extract JSON from the response
        response_text = response.strip()

        # Find JSON in the response
        json_start = response_text.find("{")
        json_end = response_text.rfind("}") + 1

        if json_start >= 0 and json_end > json_start:
            json_str = response_text[json_start:json_end]
            parsed = json.loads(json_str)

            summary = parsed.get("summary", "Summary could not be generated.")
            quiz = parsed.get("quiz", [])

            # Validate quiz format
            validated_quiz = []
            for item in quiz:
                if isinstance(item, dict) and "question" in item and "answer" in item:
                    validated_quiz.append(
                        {"question": item["question"], "answer": item["answer"]}
                    )

            return {
                "summary": summary,
                "quiz": validated_quiz if validated_quiz else _fallback_quiz(),
            }
        else:
            raise ValueError("No valid JSON found in response")

    except Exception as e:
        print(f"Summary/quiz generation error: {e}")
        # Return a basic fallback
        return {
            "summary": _generate_basic_summary(truncated_text),
            "quiz": _fallback_quiz(),
        }


def _generate_basic_summary(text: str) -> str:
    """Generate a basic extractive summary as fallback."""
    sentences = text.replace("\n", " ").split(". ")
    # Take first few sentences as a basic summary
    summary_sentences = sentences[:5]
    return ". ".join(summary_sentences) + "."


def _fallback_quiz() -> list[dict]:
    """Return fallback quiz questions when generation fails."""
    return [
        {
            "question": "What is the main topic discussed in this source?",
            "answer": "Please review the source content to determine the main topic.",
        },
        {
            "question": "What are the key takeaways from this source?",
            "answer": "Please review the source content for key takeaways.",
        },
        {
            "question": "How might the information in this source be applied?",
            "answer": "Please consider practical applications based on the source content.",
        },
    ]
