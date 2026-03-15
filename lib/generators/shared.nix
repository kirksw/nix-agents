{ lib }:
let
  cognitiveStyleText = {
    adhd = ''
      ## Cognitive Style: ADHD
      - Lead with the most important information first.
      - Use bullet points over prose wherever possible.
      - Bold key terms. Avoid walls of text.
      - Prefer short, actionable responses over comprehensive ones.
    '';
    dyslexia = ''
      ## Cognitive Style: Dyslexia
      - Use short sentences and simple words.
      - Prefer numbered lists over nested bullets.
      - Avoid dense code blocks without explanation.
      - Use clear headings for every section.
    '';
    "detail-focused" = ''
      ## Cognitive Style: Detail-Focused
      - Provide thorough justifications for decisions.
      - Call out edge cases and error conditions explicitly.
      - Include implementation rationale, not just the result.
    '';
    "high-level" = ''
      ## Cognitive Style: High-Level
      - Summarize decisions at the top before details.
      - Omit boilerplate and ceremony.
      - Escalate complexity rather than explaining it inline.
    '';
    visual = ''
      ## Cognitive Style: Visual
      - Use diagrams (Mermaid, ASCII) wherever spatial relationships help.
      - Structure output with tables when comparing options.
      - Use indentation and whitespace to show hierarchy.
    '';
  };
in
{
  mkHumanPreamble =
    human:
    let
      nameLine = if human.name != "" then "# Operator: ${human.name}\n\n" else "";
      stylePart =
        if human.cognitiveStyle != null then cognitiveStyleText.${human.cognitiveStyle} + "\n" else "";
      contextPart = if human.context != "" then "## Preferences\n\n${human.context}\n\n" else "";
      rulesPart =
        if human.rules != [ ] then
          "## Hard Rules\n\n"
          + lib.concatImapStringsSep "\n" (i: r: "${toString i}. ${r}") human.rules
          + "\n\n"
        else
          "";
      body = stylePart + contextPart + rulesPart;
    in
    if body == "" && nameLine == "" then "" else nameLine + body;
}
