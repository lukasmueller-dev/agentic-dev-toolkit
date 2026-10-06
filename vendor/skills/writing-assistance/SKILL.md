# Writing Assistance
This skill should be activated if the user asks for assistance in (re-)writing new sentences, sections, or articles.

## General writing style rules
 - Never use em-dashes. Use commas or split the sentence in two.
 - Ensure clarity, conciseness, and coherence in the writing.
 - Pay attention to the logical flow of ideas, ensuring that each sentence contributes effectively to the argument or narrative.
 - Use academic concise language. The goal is not to sound as fancy as possible but to convey our ideas, concepts, and methods to a wide audience.
 - Use "of" instead of "'s" if possible, e.g., the speed of the robot instead of the robot's speed
 - You overused these phrases in the past. Avoid them if possible:
    * emerges 
    * pioneered 
    * encompass
    * poised to become
    * paramount concern 
    * harbor
    * foster
    * of paramount importance
    * utilize
 - Use sentence length as a stylistic tool. Think about what are key messages we want to get across and use shorter sentences for these key messages. Generally, try avoiding merging too many concepts into one sentence and split the sentence if necessary.
 - Always use first-person plural ("we"). Write "we propose", "we show", "we evaluate" — never passive constructions when "we" works. Use passive only when describing system or environmental properties.
 - When describing what the proposed method does mechanistically, you can use the method name as subject ("SARA shield detects...", "Text2Interaction returns..."), not needed.
 - Support quantitative claims immediately. When a quantitative result is stated, the supporting number must follow in the same sentence. Never state a claim and defer the evidence to the next sentence.
 - No vague intensifiers. Never use "very", "quite", or "rather". Emphasize through a shorter sentence or a quantitative qualifier instead.
 - Use present tense when referring to figures and tables: "Fig. 3 shows...", "Table 1 presents...".
 - Hyphenate compound adjectives before a noun: "safety-critical", "real-world", "long-horizon", "state-of-the-art".
 - Introduce abbreviations once with the full form on first use, then use the abbreviation exclusively.
 - Use "Note that" only to flag genuinely non-obvious implications. Do not use it as a general hedge.
 - In related work and motivation, use the contrast pattern: positive claim about prior work → "However," → limitation → implication for this work. 
 - Do not add anything about our work explicitly in the related work section of a paper.

## Use-Case: Writing a new section or re-writing an existing section
 - For sections longer than one paragraph, enter /plan mode.
    1. First, identify the target audience.
    2. Come up with the core idea: Write out the core idea or core message of this section explicitly.
    3. Create a logical arc: Define the 3-6 steps to tell the story of this core idea.
    4. Define the paragraphs: For every paragraph, write out one question that this paragraph should answer.
    5. Define the sentence arc: For each paragraph, write short (5-15 words, the shorter the better) bullet points what each sentence should convey. These bullet points should answer the question of the paragraph. 
    6. Make sure every sentence contributes to the core idea.
    7. Do not write any prose until explicitly approved
 - Only after approving the writing plan, fully write out the new section.
 - Make sure to align with the general writing style rules.
 - Section-specific structural conventions:
   - **Abstract**: Follow this fixed structure: (1) motivate the problem, (2) identify the gap in current work, (3) state the proposed approach, (4) give key quantitative results. Keep it under ~150 words.
   - **Introduction**: End with an explicit numbered contribution list. Each item starts with "We..." (e.g., "We propose...", "We show...", "We evaluate..."). Include a section roadmap as the final paragraph: "The remainder of this paper is structured as follows..."
   - **Related work**: Organize thematically by approach category, not chronologically. Open each group with a clear topic sentence.
   - **Experiments**: State hypotheses explicitly before presenting results (e.g., "H1: ..., H2: ..."). Refer back to these labels when discussing results.

## Use-Case: Proofreading or refining an existing section
 - Make sure to align with the general writing style rules.
 - Identify any sentences or phrases that are ambiguous, overly complex, or unnecessarily verbose, and suggest precise and succinct alternatives.
 - Check for consistency in terminology, style, and voice throughout the document.
 - Highlight any jargon or technical terms that may need clarification for the paper's intended audience.
 - You have to include any citations as is. Do not invent citations. Always use the provided Latex citation keys.
 - Do not introduce abbreviations and keep existing abbreviations as is.
 - Keep the amount of text or information close to the original text. Ask before expanding the text further and give a good reason why you think it is necessary. Do not add boilerplate sentences at the end of a paragraph.

## Output format

All proposed text should directly be added to the document in the form:
```
===== Proposed Text =====
lorem ipsum dolor sit amet...
=========================
```
Do not delete existing text until approved.
